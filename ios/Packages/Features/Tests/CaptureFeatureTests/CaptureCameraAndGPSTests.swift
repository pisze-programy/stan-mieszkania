import AppConfigClient
import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import MediaStorage
import Testing

@testable import CaptureFeature

@Suite("CaptureFeature Camera and Optional GPS Tests")
struct CaptureCameraAndGPSTests {
  enum Fixtures {
    static let apartmentId = "01933e2a-7b40-7000-8000-000000000010"
    static let mediaId = "01933e2a-7b40-7000-8000-000000000020"
    static let baseTimestamp: TimeInterval = 1_700_000_000
    static let baseDate = Date(timeIntervalSince1970: baseTimestamp)
    static let lat = 52.2297
    static let lng = 21.0122
    static let accuracyM = 15.0
    static let width = 3_000
    static let height = 2_250
    static let bytes = 1_500_000
    static let sha256 = String(repeating: "b", count: ContractConstants.sha256HexLength)
    static let rawPhotoData = Data([0xFF, 0xD8, 0xFF, 0xD9])
    static let warsawTZ = TimeZone(identifier: "Europe/Warsaw") ?? .gmt

    static let deviceLocation = CaptureLocationMetadata(
      lat: lat,
      lng: lng,
      accuracyM: accuracyM,
      locationSource: .device
    )

    static func makeArtifact(location: CaptureLocationMetadata?) -> ProcessedPhotoArtifact {
      ProcessedPhotoArtifact(
        mediaId: mediaId,
        localFilePath: "/tmp/\(mediaId).jpg",
        sha256: sha256,
        width: width,
        height: height,
        bytes: bytes,
        capturedAt: baseDate,
        capturedTz: warsawTZ.identifier,
        capturedAtFromImport: false,
        location: location
      )
    }

    static func makeExpectedDraft(location: CaptureLocationMetadata?) -> CapturedPhotoDraft {
      CapturedPhotoDraft(
        id: mediaId,
        apartmentId: apartmentId,
        origin: .camera,
        source: .camera,
        localFilePath: "/tmp/\(mediaId).jpg",
        sha256: sha256,
        width: width,
        height: height,
        bytes: bytes,
        capturedAt: baseDate,
        capturedTz: warsawTZ.identifier,
        capturedAtFromImport: false,
        location: location
      )
    }
  }

  private actor Recorder {
    var capturedRequests: [PhotoIngestRequest] = []
    var promptDismissedCount = 0
    var successHaptics = 0

    func recordRequest(_ request: PhotoIngestRequest) { capturedRequests.append(request) }
    func recordPromptDismissed() { promptDismissedCount += 1 }
    func recordSuccessHaptic() { successHaptics += 1 }
  }

  @MainActor
  @Test("Allowing GPS opens camera only on locationPromptDidDismiss and waits for settle")
  func gpsPromptAllowOpensCameraAfterDismissAndWaitsForSettle() async {
    let recorder = Recorder()
    let expectedDraft = Fixtures.makeExpectedDraft(location: Fixtures.deviceLocation)
    let store = makeCameraStore(recorder: recorder, grantedLocation: Fixtures.deviceLocation)

    await store.send(.start) { $0.isLocationPromptPresented = true }
    await store.send(.allowLocationTapped) {
      $0.isLocationPromptPresented = false
      $0.shouldPresentCameraAfterPrompt = true
    }
    await store.receive(.locationResolved(Fixtures.deviceLocation)) {
      $0.pendingDeviceLocation = Fixtures.deviceLocation
    }
    #expect(!store.state.isPickerPresented)

    await store.send(.locationPromptDidDismiss) {
      $0.shouldPresentCameraAfterPrompt = false
      $0.isPickerPresented = true
    }
    await store.send(.cameraPhotoCaptured(Fixtures.rawPhotoData)) {
      $0.isPickerPresented = false
      $0.isProcessing = true
    }
    await store.receive(.ingestSucceeded([expectedDraft])) {
      $0.isProcessing = false
      $0.pendingDrafts = [expectedDraft]
    }
    await store.send(.pickerDismissalSettled) {
      $0.isPickerDismissalSettled = true
      $0.pendingDrafts = nil
    }
    await store.receive(.delegate(.didFinishCapture([expectedDraft], origin: .camera)))

    let requests = await recorder.capturedRequests
    #expect(requests.count == 1)
    #expect(requests.first?.source == .camera)
    #expect(requests.first?.deviceLocation == Fixtures.deviceLocation)
    #expect(await recorder.promptDismissedCount == 1)
    #expect(await recorder.successHaptics == 1)
  }

  @MainActor
  @Test("Skipping GPS prompt opens camera only after prompt dismiss and passes nil location")
  func gpsSkipAndDeniedNeverBlockCapture() async {
    let recorder = Recorder()
    let expectedDraft = Fixtures.makeExpectedDraft(location: nil)
    let skipStore = makeCameraStore(recorder: recorder, grantedLocation: nil)

    await skipStore.send(.start) { $0.isLocationPromptPresented = true }
    await skipStore.send(.skipLocationTapped) {
      $0.isLocationPromptPresented = false
      $0.shouldPresentCameraAfterPrompt = true
    }
    await skipStore.send(.locationPromptDidDismiss) {
      $0.shouldPresentCameraAfterPrompt = false
      $0.isPickerPresented = true
    }
    await skipStore.send(.cameraPhotoCaptured(Fixtures.rawPhotoData)) {
      $0.isPickerPresented = false
      $0.isProcessing = true
    }
    await skipStore.receive(.ingestSucceeded([expectedDraft])) {
      $0.isProcessing = false
      $0.pendingDrafts = [expectedDraft]
    }
    await skipStore.send(.pickerDismissalSettled) {
      $0.isPickerDismissalSettled = true
      $0.pendingDrafts = nil
    }
    await skipStore.receive(.delegate(.didFinishCapture([expectedDraft], origin: .camera)))

    let deniedStore = TestStore(
      initialState: CaptureFeature.State(apartmentId: Fixtures.apartmentId, source: .camera)
    ) {
      CaptureFeature()
    } withDependencies: {
      $0.locationCapture.authorizationStatus = { .denied }
    }
    await deniedStore.send(.start) { $0.isPickerPresented = true }

    #expect(await recorder.capturedRequests.first?.deviceLocation == nil)
    #expect(await recorder.promptDismissedCount == 1)
  }

  @MainActor
  private func makeCameraStore(
    recorder: Recorder,
    grantedLocation: CaptureLocationMetadata?
  ) -> TestStoreOf<CaptureFeature> {
    TestStore(
      initialState: CaptureFeature.State(apartmentId: Fixtures.apartmentId, source: .camera)
    ) {
      CaptureFeature()
    } withDependencies: {
      $0.date.now = Fixtures.baseDate
      $0.timeZone = Fixtures.warsawTZ
      $0.idGenerator = ClosureIDGenerator { Fixtures.mediaId }
      $0.appConfigClient.loadCachedOrDefault = { .fallbackDefaults }
      $0.locationCapture.authorizationStatus = { .notDetermined }
      $0.locationCapture.hasDismissedPrompt = { false }
      $0.locationCapture.markPromptDismissed = { Task { await recorder.recordPromptDismissed() } }
      $0.locationCapture.requestWhenInUseAuthorization = {
        grantedLocation != nil ? .authorized : .denied
      }
      $0.locationCapture.captureCurrentLocation = { grantedLocation }
      $0.mediaStorage.ingestPhoto = { request in
        Task { await recorder.recordRequest(request) }
        return Fixtures.makeArtifact(location: request.deviceLocation)
      }
      $0.haptics = HapticsClient(
        markerDropped: {},
        actionSucceeded: { Task { await recorder.recordSuccessHaptic() } },
        warning: {},
        error: {}
      )
    }
  }
}
