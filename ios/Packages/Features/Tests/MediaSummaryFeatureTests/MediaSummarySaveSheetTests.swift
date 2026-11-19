import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import SQLiteData
import SyncEngine
import Testing

@testable import MediaSummaryFeature

@Suite("MediaSummaryFeature Toolbar Save Sheet Tests")
struct MediaSummarySaveSheetTests {
  @MainActor
  @Test("Validation failure surfaces error toast on summary without opening save sheet")
  func validationFailureBlocksSaveSheet() async {
    let warningHaptics = LockIsolated(0)
    var state = MediaSummaryFeature.State(
      apartmentId: MediaSummaryTestFixtures.apartmentId,
      drafts: [MediaSummaryTestFixtures.makeDraft(origin: .camera)],
      origin: .camera,
      currentUser: MediaSummaryTestFixtures.author
    )
    state.pages[0].description = String(
      repeating: "a",
      count: ContractConstants.entryTextMaxLength + 1
    )

    let store = TestStore(initialState: state) {
      MediaSummaryFeature()
    } withDependencies: {
      $0.haptics.warning = { warningHaptics.withValue { $0 += 1 } }
    }

    await store.send(.saveButtonTapped) {
      $0.errorMessage = L10n.errorMessage(for: .entryValidationFailed)
    }
    #expect(!store.state.isSaveSheetPresented)
    #expect(warningHaptics.value == 1)
  }

  @MainActor
  @Test("Save sheet sequences dismissal before delegate, blocks dismiss while saving, keeps errors")
  func saveSheetLifecycleAndErrorHandling() async throws {
    let database = try MediaSummaryTestFixtures.seedApartmentDatabase()
    let errorHaptics = LockIsolated(0)
    let successHaptics = LockIsolated(0)
    let store = makeSaveSheetStore(
      database: database,
      errorHaptics: errorHaptics,
      successHaptics: successHaptics
    )

    await store.send(.saveButtonTapped) { $0.isSaveSheetPresented = true }
    await store.send(.saveSheetDismissed) { $0.isSaveSheetPresented = false }
    await store.send(.saveButtonTapped) { $0.isSaveSheetPresented = true }

    await store.send(.saveFailed("Błąd zapisu")) { $0.saveErrorMessage = "Błąd zapisu" }
    #expect(store.state.isSaveSheetPresented && errorHaptics.value == 1)

    await store.send(.saveTapped(mode: .cloud)) {
      $0.savingMode = .cloud
      $0.saveErrorMessage = nil
    }
    await store.receive(.saveSucceeded(mode: .cloud)) {
      $0.savingMode = nil
      $0.pendingSavedMode = .cloud
      $0.isSaveSheetPresented = false
    }
    await store.send(.saveSheetDidDismiss) { $0.pendingSavedMode = nil }
    await store.receive(.delegate(.didSave(mode: .cloud)))
    #expect(successHaptics.value == 1)
  }

  @MainActor
  @Test("Save sheet ignores dismissal while save is in flight")
  func saveSheetDismissedIgnoredWhileSaving() async {
    let store = TestStore(
      initialState: MediaSummaryFeature.State(
        apartmentId: MediaSummaryTestFixtures.apartmentId,
        drafts: [MediaSummaryTestFixtures.makeDraft(origin: .camera)],
        origin: .camera,
        currentUser: MediaSummaryTestFixtures.author,
        isSaveSheetPresented: true,
        savingMode: .cloud
      )
    ) {
      MediaSummaryFeature()
    }
    await store.send(.saveSheetDismissed)
    #expect(store.state.isSaveSheetPresented)
  }

  @MainActor
  private func makeSaveSheetStore(
    database: any DatabaseWriter,
    errorHaptics: LockIsolated<Int>,
    successHaptics: LockIsolated<Int>
  ) -> TestStoreOf<MediaSummaryFeature> {
    TestStore(
      initialState: MediaSummaryFeature.State(
        apartmentId: MediaSummaryTestFixtures.apartmentId,
        drafts: [MediaSummaryTestFixtures.makeDraft(origin: .camera)],
        origin: .camera,
        currentUser: MediaSummaryTestFixtures.author
      )
    ) {
      MediaSummaryFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.date.now = MediaSummaryTestFixtures.captureDate
      $0.idGenerator = MediaSummaryTestFixtures.makeIDGenerator([
        MediaSummaryTestFixtures.outboxOneId
      ])
      $0.syncEngine.processOutbox = {
        SyncOutboxReport(
          processedCount: 1,
          failedCount: 0,
          deferredCount: 0,
          pausedForForceUpdate: false
        )
      }
      $0.haptics.error = { errorHaptics.withValue { $0 += 1 } }
      $0.haptics.actionSucceeded = { successHaptics.withValue { $0 += 1 } }
    }
  }
}
