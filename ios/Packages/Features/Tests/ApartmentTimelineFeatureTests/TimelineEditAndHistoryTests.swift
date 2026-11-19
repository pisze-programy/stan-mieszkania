import APIClient
import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import SQLiteData
import SyncEngine
import Testing

@testable import ApartmentTimelineFeature

@Suite("ApartmentTimelineFeature Edit and History Tests")
struct TimelineEditAndHistoryTests {
  private actor EditRecorder {
    var outboxFlushes = 0
    func recordOutbox() { outboxFlushes += 1 }
  }

  private static let offlineHTTPStatus = 503
  private static let processedReport = SyncOutboxReport(
    processedCount: 1,
    failedCount: 0,
    deferredCount: 0,
    pausedForForceUpdate: false
  )

  @MainActor
  @Test("Owner edits apartment metadata with validation and outbox sync")
  func ownerEditMetadataFlow() async throws {
    let database = try TimelineTestFixtures.seedTimelineDatabase(role: .owner)
    let recorder = EditRecorder()
    let successHaptics = LockIsolated(0)
    let warningHaptics = LockIsolated(0)
    let store = try makeOwnerEditStore(
      database: database,
      recorder: recorder,
      successHaptics: successHaptics,
      warningHaptics: warningHaptics
    )

    await store.send(.editMenuTapped) {
      $0.editSheet = EditApartmentSheetState(
        name: "Kawalerka Mokotów",
        street: "Puławska 10",
        city: "Warszawa"
      )
    }
    await store.send(.editNameChanged("   ")) { $0.editSheet?.name = "   " }
    await store.send(.editSubmitted) {
      $0.editSheet?.errorMessage = L10n.errorMessage(for: .apartmentValidationFailed)
    }
    await store.send(.editNameChanged("Apartament Śródmieście")) {
      $0.editSheet?.name = "Apartament Śródmieście"
      $0.editSheet?.errorMessage = nil
    }
    await store.send(.editSubmitted) { $0.editSheet?.isSaving = true }

    let updated = try ApartmentTimelineStore.fetchSnapshot(
      apartmentId: TimelineTestFixtures.apartmentId,
      from: database,
      calendar: TimelineTestFixtures.warsawCalendar,
      timeZone: TimelineTestFixtures.warsawTimeZone
    )
    await store.receive(.editSucceeded(updated)) {
      $0.editSheet = nil
      $0.apartment = updated.apartment
      $0.localUnsyncedCount = updated.localUnsyncedCount
      $0.cloudMediaCount = updated.cloudMediaCount
    }
    #expect(store.state.apartment?.name == "Apartament Śródmieście")
    #expect(await recorder.outboxFlushes == 1)
    #expect(successHaptics.value == 1)
    #expect(warningHaptics.value == 1)
  }

  @MainActor
  @Test("Contributor cannot open owner apartment edit sheet")
  func contributorCannotEditApartment() async {
    let store = TestStore(
      initialState: ApartmentTimelineFeature.State(
        apartmentId: TimelineTestFixtures.apartmentId,
        apartment: TimelineTestFixtures.makeApartment(role: .contributor)
      )
    ) {
      ApartmentTimelineFeature()
    }
    await store.send(.editMenuTapped)
    #expect(store.state.editSheet == nil)
  }

  @MainActor
  @Test("Change history loads remote entries and preserves local fallback offline")
  func changeHistoryRemoteAndOfflineFallback() async throws {
    let database = try TimelineTestFixtures.seedTimelineDatabase(role: .owner)
    let change = ApartmentChange(
      id: TimelineTestFixtures.changeId,
      apartmentId: TimelineTestFixtures.apartmentId,
      authorId: TimelineTestFixtures.ownerId,
      field: .name,
      oldValue: "Stara nazwa",
      newValue: "Kawalerka Mokotów",
      createdAt: TimelineTestFixtures.thursdayDate
    )
    let authors = [
      TimelineTestFixtures.ownerId: TimelineTestFixtures.ownerUser.displayName,
      TimelineTestFixtures.contributorId: TimelineTestFixtures.contributorUser.displayName,
    ]

    let onlineStore = makeHistoryStore(database: database, remoteResult: .success([change]))
    await onlineStore.send(.historyMenuTapped) {
      $0.historySheet = ApartmentHistorySheetState(
        changes: [],
        authorNames: authors,
        isLoading: true
      )
    }
    await onlineStore.receive(.historyLoaded(changes: [change], authorNames: authors)) {
      $0.historySheet?.changes = [change]
      $0.historySheet?.isLoading = false
    }
    await onlineStore.send(.historySheetDismissed) { $0.historySheet = nil }

    let offlineError = APIProblemError(
      status: Self.offlineHTTPStatus,
      code: .known(.internalError),
      title: "Offline",
      detail: "Offline"
    )
    let offlineStore = makeHistoryStore(database: database, remoteResult: .failure(offlineError))
    await offlineStore.send(.historyMenuTapped) {
      $0.historySheet = ApartmentHistorySheetState(
        changes: [change],
        authorNames: authors,
        isLoading: true
      )
    }
    await offlineStore.receive(.historyFailed(L10n.errorMessage(for: .internalError))) {
      $0.historySheet?.isLoading = false
    }
    #expect(offlineStore.state.historySheet?.changes == [change])
    #expect(offlineStore.state.historySheet?.errorMessage == nil)
  }

  @MainActor
  private func makeOwnerEditStore(
    database: any DatabaseWriter,
    recorder: EditRecorder,
    successHaptics: LockIsolated<Int>,
    warningHaptics: LockIsolated<Int>
  ) throws -> TestStoreOf<ApartmentTimelineFeature> {
    let snapshot = try ApartmentTimelineStore.fetchSnapshot(
      apartmentId: TimelineTestFixtures.apartmentId,
      from: database,
      calendar: TimelineTestFixtures.warsawCalendar,
      timeZone: TimelineTestFixtures.warsawTimeZone
    )
    return TestStore(
      initialState: ApartmentTimelineFeature.State(
        apartmentId: TimelineTestFixtures.apartmentId,
        apartment: snapshot.apartment,
        sections: snapshot.sections
      )
    ) {
      ApartmentTimelineFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.calendar = TimelineTestFixtures.warsawCalendar
      $0.timeZone = TimelineTestFixtures.warsawTimeZone
      $0.date.now = TimelineTestFixtures.thursdayLaterDate
      $0.idGenerator = SequenceIDGenerator(
        values: [TimelineTestFixtures.outboxId, TimelineTestFixtures.changeId]
      )
      $0.syncEngine.processOutbox = {
        await recorder.recordOutbox()
        return Self.processedReport
      }
      $0.haptics.actionSucceeded = { successHaptics.withValue { $0 += 1 } }
      $0.haptics.warning = { warningHaptics.withValue { $0 += 1 } }
    }
  }

  @MainActor
  private func makeHistoryStore(
    database: any DatabaseWriter,
    remoteResult: Result<[ApartmentChange], APIProblemError>
  ) -> TestStoreOf<ApartmentTimelineFeature> {
    TestStore(
      initialState: ApartmentTimelineFeature.State(
        apartmentId: TimelineTestFixtures.apartmentId,
        apartment: TimelineTestFixtures.makeApartment(role: .owner)
      )
    ) {
      ApartmentTimelineFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.apiClient.listApartmentHistory = { _ in try remoteResult.get() }
    }
  }
}
