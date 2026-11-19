import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import SQLiteData
import SyncEngine
import Testing

@testable import MediaSummaryFeature

@Suite("MediaSummaryFeature Save Modes and Disk Cleanup Tests")
struct MediaSummarySaveAndCleanupTests {
  private static let markerX = 0.3
  private static let markerY = 0.7
  private static let twoOutboxOps = 2
  private static let twoPhotosCount = 2

  @MainActor
  @Test("Lokalnie tracks savingMode=.localOnly and saves to SQLiteData without outbox ops")
  func saveLocalOnlyPersistsWithoutOutbox() async throws {
    let database = try MediaSummaryTestFixtures.seedApartmentDatabase()
    let successHaptics = LockIsolated(0)
    let drafts = [
      MediaSummaryTestFixtures.makeDraft(id: MediaSummaryTestFixtures.draftOneId),
      MediaSummaryTestFixtures.makeDraft(id: MediaSummaryTestFixtures.draftTwoId),
    ]
    var initialState = MediaSummaryFeature.State(
      apartmentId: MediaSummaryTestFixtures.apartmentId,
      drafts: drafts,
      origin: .photoLibrary,
      currentUser: MediaSummaryTestFixtures.author
    )
    let marker = SummaryDraftMarker(
      id: MediaSummaryTestFixtures.markerOneId,
      number: 1,
      x: Self.markerX,
      y: Self.markerY
    )
    initialState.pages[0].description = "Rysa [1]"
    initialState.pages[0].markers = [marker]

    let store = TestStore(initialState: initialState) {
      MediaSummaryFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.date.now = MediaSummaryTestFixtures.captureDate
      $0.idGenerator = MediaSummaryTestFixtures.makeIDGenerator([
        MediaSummaryTestFixtures.entryOneId
      ])
      $0.haptics.actionSucceeded = { successHaptics.withValue { $0 += 1 } }
    }

    await store.send(.saveTapped(mode: .localOnly)) { $0.savingMode = .localOnly }
    #expect(store.state.isSaving)
    await store.receive(.saveSucceeded(mode: .localOnly)) { $0.savingMode = nil }
    await store.receive(.delegate(.didSave(mode: .localOnly)))

    let mediaRows = try await database.read { try MediaRecord.fetchAll($0) }
    let entryRows = try await database.read { try EntryRecord.fetchAll($0) }
    let markerRows = try await database.read { try MarkerRecord.fetchAll($0) }
    let outboxRows = try OutboxRepository(database: database).fetchAllOperations()

    #expect(mediaRows.count == Self.twoPhotosCount)
    #expect(mediaRows.allSatisfy { $0.syncState == MediaSyncState.localOnly.rawValue })
    #expect(entryRows.count == 1)
    #expect(entryRows[0].text == "Rysa [1]")
    #expect(markerRows.count == 1)
    #expect(outboxRows.isEmpty)
    #expect(successHaptics.value == 1)
  }

  @MainActor
  @Test("Chmura tracks savingMode=.cloud, queues outbox ops, and triggers processOutbox")
  func saveToCloudQueuesOutboxAndReturnsImmediately() async throws {
    let database = try MediaSummaryTestFixtures.seedApartmentDatabase()
    let outboxCalls = LockIsolated(0)
    let successHaptics = LockIsolated(0)
    var initialState = MediaSummaryFeature.State(
      apartmentId: MediaSummaryTestFixtures.apartmentId,
      drafts: [MediaSummaryTestFixtures.makeDraft(origin: .camera)],
      origin: .camera,
      currentUser: MediaSummaryTestFixtures.author
    )
    initialState.pages[0].description = "Uszkodzony zamek"

    let store = TestStore(initialState: initialState) {
      MediaSummaryFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.date.now = MediaSummaryTestFixtures.captureDate
      $0.idGenerator = MediaSummaryTestFixtures.makeIDGenerator([
        MediaSummaryTestFixtures.entryOneId,
        MediaSummaryTestFixtures.outboxOneId,
        MediaSummaryTestFixtures.outboxTwoId,
      ])
      $0.syncEngine.processOutbox = {
        outboxCalls.withValue { $0 += 1 }
        return SyncOutboxReport(
          processedCount: Self.twoOutboxOps,
          failedCount: 0,
          deferredCount: 0,
          pausedForForceUpdate: false
        )
      }
      $0.haptics.actionSucceeded = { successHaptics.withValue { $0 += 1 } }
    }

    await store.send(.saveTapped(mode: .cloud)) { $0.savingMode = .cloud }
    await store.receive(.saveSucceeded(mode: .cloud)) { $0.savingMode = nil }
    await store.receive(.delegate(.didSave(mode: .cloud)))

    let mediaRows = try await database.read { try MediaRecord.fetchAll($0) }
    let outboxRows = try OutboxRepository(database: database).fetchAllOperations()

    #expect(mediaRows.count == 1)
    #expect(mediaRows[0].syncState == MediaSyncState.queued.rawValue)
    #expect(outboxRows.count == Self.twoOutboxOps)
    #expect(outboxRows[0].operationType == OutboxOperationType.uploadMedia.rawValue)
    #expect(outboxRows[1].operationType == OutboxOperationType.createEntry.rawValue)
    #expect(outboxCalls.value == 1)
    #expect(successHaptics.value == 1)
  }

  @MainActor
  @Test("saveFailed clears savingMode and surfaces error toast message")
  func saveFailedClearsSavingMode() async {
    let errorHaptics = LockIsolated(0)
    let store = TestStore(
      initialState: MediaSummaryFeature.State(
        apartmentId: MediaSummaryTestFixtures.apartmentId,
        drafts: [MediaSummaryTestFixtures.makeDraft(origin: .camera)],
        origin: .camera,
        currentUser: MediaSummaryTestFixtures.author,
        savingMode: .cloud
      )
    ) {
      MediaSummaryFeature()
    } withDependencies: {
      $0.haptics.error = { errorHaptics.withValue { $0 += 1 } }
    }

    await store.send(.saveFailed("Błąd zapisu")) {
      $0.savingMode = nil
      $0.errorMessage = "Błąd zapisu"
    }
    #expect(!store.state.isSaving)
    #expect(errorHaptics.value == 1)
  }

  @MainActor
  @Test("Cancel cleans up unsaved files, emits cancel delegate, and view instantiates cleanly")
  func cancelCleansUpDiskFilesAndViewInstantiates() async {
    let deletedFiles = LockIsolated<[String]>([])
    let draft = MediaSummaryTestFixtures.makeDraft(origin: .files)
    let store = makeCleanupStore(drafts: [draft], origin: .files, deletedFiles: deletedFiles)

    await store.send(.cancelTapped)
    await store.receive(.delegate(.didCancel))
    #expect(deletedFiles.value == [MediaSummaryTestFixtures.draftOneId])

    let viewStore = Store(
      initialState: MediaSummaryFeature.State(
        apartmentId: MediaSummaryTestFixtures.apartmentId,
        drafts: [draft],
        origin: .camera,
        currentUser: MediaSummaryTestFixtures.author
      )
    ) {
      MediaSummaryFeature()
    }
    _ = MediaSummaryView(store: viewStore)
  }

  @MainActor
  private func makeCleanupStore(
    drafts: [CapturedPhotoDraft],
    origin: CaptureSourceKind,
    deletedFiles: LockIsolated<[String]>
  ) -> TestStoreOf<MediaSummaryFeature> {
    TestStore(
      initialState: MediaSummaryFeature.State(
        apartmentId: MediaSummaryTestFixtures.apartmentId,
        drafts: drafts,
        origin: origin,
        currentUser: MediaSummaryTestFixtures.author
      )
    ) {
      MediaSummaryFeature()
    } withDependencies: {
      $0.mediaStorage.deleteLocalFile = { id in deletedFiles.withValue { $0.append(id) } }
    }
  }
}
