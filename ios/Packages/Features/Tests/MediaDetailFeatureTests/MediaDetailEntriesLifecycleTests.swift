import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import SQLiteData
import SyncEngine
import Testing

@testable import MediaDetailFeature

@Suite("MediaDetailFeature Local Edit and Synced Retraction Tests")
struct MediaDetailEntriesLifecycleTests {
  @MainActor
  @Test("Local unsynced entry supports author edit and hard-delete without cloud outbox")
  func localEntryEditAndHardDelete() async throws {
    let database = try MediaDetailTestFixtures.seedDatabase(
      activeRole: .owner,
      isVerifiedMedia: false
    )
    let store = try makeStore(database: database, selectedMarkerNumber: nil, outboxCalls: nil)

    let draftMarker = DetailDraftMarker(
      id: MediaDetailTestFixtures.markerOneId,
      number: 1,
      x: MediaDetailTestFixtures.markerOneCoord,
      y: MediaDetailTestFixtures.markerOneCoord
    )
    await store.send(.editLocalEntryTapped(MediaDetailTestFixtures.entryOneId)) {
      $0.composer = EntryComposerState(
        editingEntryId: MediaDetailTestFixtures.entryOneId,
        text: "Rysa na drzwiach [1]",
        markers: [draftMarker]
      )
    }
    await store.send(.composerTextChanged("Głęboka rysa [1]")) {
      $0.composer?.text = "Głęboka rysa [1]"
    }
    await store.send(.composerSubmitted) { $0.composer?.isSubmitting = true }

    let edited = try MediaDetailStore.fetchSnapshot(
      mediaId: MediaDetailTestFixtures.mediaId,
      from: database
    )
    await store.receive(.composerSucceeded(edited)) {
      $0.composer = nil
      $0.entries = edited.entries
    }
    #expect(store.state.entries[0].entry.text == "Głęboka rysa [1]")

    await store.send(.entryDeleteTapped(MediaDetailTestFixtures.entryOneId)) {
      $0.entryDeleteConfirmation = .hardDeleteLocal(entryId: MediaDetailTestFixtures.entryOneId)
    }
    await store.send(.entryDeleteConfirmed)

    let afterDelete = try MediaDetailStore.fetchSnapshot(
      mediaId: MediaDetailTestFixtures.mediaId,
      from: database
    )
    await store.receive(.entryDeleteSucceeded(afterDelete, shouldSyncOutbox: false)) {
      $0.entryDeleteConfirmation = nil
      $0.entries = []
    }
    #expect(try OutboxRepository(database: database).fetchAllOperations().isEmpty)
  }

  @MainActor
  @Test("Synced entry retracts via outbox, hides markers, and formats Polish placeholder")
  func syncedEntryRetractionHidesMarkers() async throws {
    let database = try MediaDetailTestFixtures.seedDatabase(
      activeRole: .owner,
      isVerifiedMedia: true
    )
    let outboxCalls = LockIsolated(0)
    let store = try makeStore(database: database, selectedMarkerNumber: 1, outboxCalls: outboxCalls)

    await store.send(.editLocalEntryTapped(MediaDetailTestFixtures.entryOneId))
    await store.send(.entryDeleteTapped(MediaDetailTestFixtures.entryOneId)) {
      $0.entryDeleteConfirmation = .retractSynced(entryId: MediaDetailTestFixtures.entryOneId)
    }
    await store.send(.entryDeleteConfirmed)

    let retracted = try MediaDetailStore.fetchSnapshot(
      mediaId: MediaDetailTestFixtures.mediaId,
      from: database
    )
    await store.receive(.entryDeleteSucceeded(retracted, shouldSyncOutbox: true)) {
      $0.entryDeleteConfirmation = nil
      $0.entries = retracted.entries
      $0.selectedMarkerNumber = nil
    }

    #expect(store.state.entries[0].entry.isRetracted)
    #expect(store.state.entries[0].entry.text.isEmpty)
    #expect(store.state.overlayMarkers.map(\.number) == [MediaDetailTestFixtures.markerTwoNumber])
    #expect(outboxCalls.value == 1)

    let placeholder = L10n.format(
      "media.detail.entry.retracted",
      MediaDetailTestFixtures.ownerUser.displayName,
      PolishDateFormatters.formatTimestamp(MediaDetailTestFixtures.laterDate)
    )
    #expect(placeholder.hasPrefix("Wpis wycofany przez Jan Kowalski, "))
  }

  @MainActor
  private func makeStore(
    database: any DatabaseWriter,
    selectedMarkerNumber: Int?,
    outboxCalls: LockIsolated<Int>?
  ) throws -> TestStoreOf<MediaDetailFeature> {
    let snapshot = try MediaDetailStore.fetchSnapshot(
      mediaId: MediaDetailTestFixtures.mediaId,
      from: database
    )
    return TestStore(
      initialState: MediaDetailFeature.State(
        apartmentId: MediaDetailTestFixtures.apartmentId,
        mediaId: MediaDetailTestFixtures.mediaId,
        media: snapshot.media,
        mediaAuthorName: snapshot.mediaAuthorName,
        mediaAuthorColorHex: snapshot.mediaAuthorColorHex,
        entries: snapshot.entries,
        currentUser: snapshot.currentUser,
        selectedMarkerNumber: selectedMarkerNumber
      )
    ) {
      MediaDetailFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.date.now = MediaDetailTestFixtures.laterDate
      $0.idGenerator = MediaDetailTestFixtures.makeIDGenerator([MediaDetailTestFixtures.outboxId])
      $0.haptics.actionSucceeded = {}
      if let outboxCalls {
        $0.syncEngine.processOutbox = {
          outboxCalls.withValue { $0 += 1 }
          return SyncOutboxReport(
            processedCount: 1,
            failedCount: 0,
            deferredCount: 0,
            pausedForForceUpdate: false
          )
        }
      }
    }
  }
}
