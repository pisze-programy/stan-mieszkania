import AppConfigClient
import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import MediaStorage
import Testing

@testable import CaptureFeature

@Suite("CaptureFeature Multi-Photo Import, Error, and Cancellation Tests")
struct CaptureImportAndErrorTests {
  private enum Fixtures {
    static let apartmentId = "01933e2a-7b40-7000-8000-000000000010"
    static let firstMediaId = "01933e2a-7b40-7000-8000-000000000031"
    static let secondMediaId = "01933e2a-7b40-7000-8000-000000000032"
    static let baseTimestamp: TimeInterval = 1_700_000_000
    static let baseDate = Date(timeIntervalSince1970: baseTimestamp)
    static let width = 1_600
    static let height = 1_200
    static let bytes = 500_000
    static let sha256 = String(repeating: "c", count: ContractConstants.sha256HexLength)
    static let firstData = Data([0x01, 0x02])
    static let secondData = Data([0x03, 0x04])
    static let warsawTZ = TimeZone(identifier: "Europe/Warsaw") ?? .gmt
  }

  private actor Recorder {
    var deletedMediaIds: [String] = []
    var ingestedOrder: [String] = []
    var errorHaptics = 0

    func recordDeleted(_ id: String) { deletedMediaIds.append(id) }
    func recordIngested(_ id: String) { ingestedOrder.append(id) }
    func recordErrorHaptic() { errorHaptics += 1 }
  }

  @MainActor
  @Test("Multi-photo gallery import ingests sequentially preserving order")
  func multiPhotoImportPreservesOrder() async {
    let recorder = Recorder()
    let ids = LockIsolated([Fixtures.firstMediaId, Fixtures.secondMediaId])
    let expectedDrafts = [
      makeDraft(id: Fixtures.firstMediaId, origin: .photoLibrary),
      makeDraft(id: Fixtures.secondMediaId, origin: .photoLibrary),
    ]

    let store = TestStore(
      initialState: CaptureFeature.State(apartmentId: Fixtures.apartmentId, source: .photoLibrary)
    ) {
      CaptureFeature()
    } withDependencies: {
      $0.date.now = Fixtures.baseDate
      $0.timeZone = Fixtures.warsawTZ
      $0.idGenerator = ClosureIDGenerator { ids.withValue { $0.removeFirst() } }
      $0.appConfigClient.loadCachedOrDefault = { .fallbackDefaults }
      $0.mediaStorage.ingestPhoto = { request in
        Task { await recorder.recordIngested(request.mediaId) }
        return makeArtifact(id: request.mediaId)
      }
    }

    await store.send(.task) {
      $0.isPickerPresented = true
    }
    await store.send(.importedPhotosSelected([Fixtures.firstData, Fixtures.secondData])) {
      $0.isPickerPresented = false
      $0.isProcessing = true
    }
    await store.receive(.ingestSucceeded(expectedDrafts)) {
      $0.isProcessing = false
    }
    await store.receive(.delegate(.didFinishCapture(expectedDrafts, origin: .photoLibrary)))
    #expect(await recorder.ingestedOrder == [Fixtures.firstMediaId, Fixtures.secondMediaId])
  }

  @MainActor
  @Test("Partial import failure cleans up earlier local files and reports localized error")
  func partialImportFailureCleansUp() async {
    let recorder = Recorder()
    let ids = LockIsolated([Fixtures.firstMediaId, Fixtures.secondMediaId])

    let store = TestStore(
      initialState: CaptureFeature.State(apartmentId: Fixtures.apartmentId, source: .files)
    ) {
      CaptureFeature()
    } withDependencies: {
      $0.date.now = Fixtures.baseDate
      $0.timeZone = Fixtures.warsawTZ
      $0.idGenerator = ClosureIDGenerator { ids.withValue { $0.removeFirst() } }
      $0.appConfigClient.loadCachedOrDefault = { .fallbackDefaults }
      $0.mediaStorage.ingestPhoto = { request in
        if request.mediaId == Fixtures.secondMediaId {
          throw MediaStorageError.invalidImageData
        }
        return makeArtifact(id: request.mediaId)
      }
      $0.mediaStorage.deleteLocalFile = { mediaId in
        Task { await recorder.recordDeleted(mediaId) }
      }
      $0.haptics = HapticsClient(
        markerDropped: {},
        actionSucceeded: {},
        warning: {},
        error: { Task { await recorder.recordErrorHaptic() } }
      )
    }

    await store.send(.importedPhotosSelected([Fixtures.firstData, Fixtures.secondData])) {
      $0.isProcessing = true
    }
    let expectedError = L10n.string("capture.import.failed")
    await store.receive(.ingestFailed(expectedError)) {
      $0.isProcessing = false
      $0.errorMessage = expectedError
    }
    await store.send(.dismissError) {
      $0.errorMessage = nil
    }

    #expect(await recorder.deletedMediaIds == [Fixtures.firstMediaId])
    #expect(await recorder.errorHaptics == 1)
  }

  @MainActor
  @Test("Cancellation emits didCancel delegate and CaptureView instantiates cleanly")
  func cancellationAndViews() async {
    let store = TestStore(
      initialState: CaptureFeature.State(
        apartmentId: Fixtures.apartmentId,
        source: .photoLibrary,
        isPickerPresented: true
      )
    ) {
      CaptureFeature()
    }

    await store.send(.pickerCancelled) {
      $0.isPickerPresented = false
    }
    await store.receive(.delegate(.didCancel))

    let viewStore = Store(
      initialState: CaptureFeature.State(apartmentId: Fixtures.apartmentId, source: .camera)
    ) {
      CaptureFeature()
    }
    let view = CaptureView(store: viewStore)
    let promptView = LocationPermissionSheetView(onAllowTapped: {}, onSkipTapped: {})
    _ = (view, promptView)
  }

  private func makeArtifact(id: String) -> ProcessedPhotoArtifact {
    ProcessedPhotoArtifact(
      mediaId: id,
      localFilePath: "/tmp/\(id).jpg",
      sha256: Fixtures.sha256,
      width: Fixtures.width,
      height: Fixtures.height,
      bytes: Fixtures.bytes,
      capturedAt: Fixtures.baseDate,
      capturedTz: Fixtures.warsawTZ.identifier,
      capturedAtFromImport: true,
      location: nil
    )
  }

  private func makeDraft(id: String, origin: CaptureSourceKind) -> CapturedPhotoDraft {
    CapturedPhotoDraft(
      id: id,
      apartmentId: Fixtures.apartmentId,
      origin: origin,
      source: .imported,
      localFilePath: "/tmp/\(id).jpg",
      sha256: Fixtures.sha256,
      width: Fixtures.width,
      height: Fixtures.height,
      bytes: Fixtures.bytes,
      capturedAt: Fixtures.baseDate,
      capturedTz: Fixtures.warsawTZ.identifier,
      capturedAtFromImport: true,
      location: nil
    )
  }
}
