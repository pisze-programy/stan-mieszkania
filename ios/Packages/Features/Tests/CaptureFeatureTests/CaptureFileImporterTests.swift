import AppConfigClient
import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import MediaStorage
import Testing

@testable import CaptureFeature

@Suite("CaptureFeature FileImporter Settle Tests")
struct CaptureFileImporterTests {
  private enum Fixtures {
    static let apartmentId = "01933e2a-7b40-7000-8000-000000000010"
    static let mediaId = "01933e2a-7b40-7000-8000-000000000041"
    static let baseTimestamp: TimeInterval = 1_700_000_000
    static let baseDate = Date(timeIntervalSince1970: baseTimestamp)
    static let width = 1_600
    static let height = 1_200
    static let bytes = 500_000
    static let sha256 = String(repeating: "d", count: ContractConstants.sha256HexLength)
    static let rawData = Data([0x01, 0x02])
    static let warsawTZ = TimeZone(identifier: "Europe/Warsaw") ?? .gmt

    static let artifact = ProcessedPhotoArtifact(
      mediaId: mediaId,
      localFilePath: "/tmp/\(mediaId).jpg",
      sha256: sha256,
      width: width,
      height: height,
      bytes: bytes,
      capturedAt: baseDate,
      capturedTz: warsawTZ.identifier,
      capturedAtFromImport: true,
      location: nil
    )

    static let expectedDraft = CapturedPhotoDraft(
      id: mediaId,
      apartmentId: apartmentId,
      origin: .files,
      source: .imported,
      localFilePath: "/tmp/\(mediaId).jpg",
      sha256: sha256,
      width: width,
      height: height,
      bytes: bytes,
      capturedAt: baseDate,
      capturedTz: warsawTZ.identifier,
      capturedAtFromImport: true,
      location: nil
    )
  }

  @MainActor
  @Test("Files import settles dismissal without pickerDismissed and emits didFinishCapture")
  func filesImportSettlesWithoutPickerDismissed() async {
    let clock = TestClock()
    let store = TestStore(
      initialState: CaptureFeature.State(apartmentId: Fixtures.apartmentId, source: .files)
    ) {
      CaptureFeature()
    } withDependencies: {
      $0.continuousClock = clock
      $0.date.now = Fixtures.baseDate
      $0.timeZone = Fixtures.warsawTZ
      $0.idGenerator = ClosureIDGenerator { Fixtures.mediaId }
      $0.appConfigClient.loadCachedOrDefault = { .fallbackDefaults }
      $0.mediaStorage.ingestPhoto = { _ in Fixtures.artifact }
    }

    await store.send(.start) { $0.isPickerPresented = true }
    await store.send(.importedPhotosSelected([Fixtures.rawData])) {
      $0.isPickerPresented = false
      $0.isProcessing = true
    }
    await store.receive(.ingestSucceeded([Fixtures.expectedDraft])) {
      $0.isProcessing = false
      $0.pendingDrafts = [Fixtures.expectedDraft]
    }
    await clock.advance(by: CaptureConstants.presentationSettleDelay)
    await store.receive(.pickerDismissalSettled) {
      $0.isPickerDismissalSettled = true
      $0.pendingDrafts = nil
    }
    await store.receive(.delegate(.didFinishCapture([Fixtures.expectedDraft], origin: .files)))
  }

  @MainActor
  @Test("Files synchronous ingestFailed closes picker, settles for alert, and dismisses cleanly")
  func filesIngestFailedSettlesForAlertAndDismisses() async {
    let clock = TestClock()
    let store = TestStore(
      initialState: CaptureFeature.State(apartmentId: Fixtures.apartmentId, source: .files)
    ) {
      CaptureFeature()
    } withDependencies: {
      $0.continuousClock = clock
    }

    let expectedError = L10n.string("capture.import.failed")
    await store.send(.start) { $0.isPickerPresented = true }
    await store.send(.ingestFailed(expectedError)) {
      $0.isPickerPresented = false
      $0.errorMessage = expectedError
    }
    await clock.advance(by: CaptureConstants.presentationSettleDelay)
    await store.receive(.pickerDismissalSettled) { $0.isPickerDismissalSettled = true }
    await store.send(.dismissError) { $0.errorMessage = nil }
    await store.receive(.delegate(.didCancel))
  }
}
