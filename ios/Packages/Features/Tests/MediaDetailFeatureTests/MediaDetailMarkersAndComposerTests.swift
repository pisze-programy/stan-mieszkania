import ComposableArchitecture
import Database
import Domain
import Foundation
import SQLiteData
import SyncEngine
import Testing

@testable import MediaDetailFeature

@Suite("MediaDetailFeature Markers and Contributor Composer Tests")
struct MediaDetailMarkersAndComposerTests {
  private static let markerTwoNumber = 2
  private static let markerThreeNumber = 3
  private static let markerThreeX = 0.75
  private static let markerThreeY = 0.35

  @MainActor
  @Test("Tapping marker highlights [n] and sets scrollTargetEntryId; outside tap deselects")
  func markerSelectionScrollTargetAndDeselection() async throws {
    let database = try MediaDetailTestFixtures.seedDatabase(
      activeRole: .owner,
      isVerifiedMedia: true
    )
    let snapshot = try MediaDetailStore.fetchSnapshot(
      mediaId: MediaDetailTestFixtures.mediaId,
      from: database
    )

    let store = TestStore(
      initialState: MediaDetailFeature.State(
        apartmentId: MediaDetailTestFixtures.apartmentId,
        mediaId: MediaDetailTestFixtures.mediaId
      )
    ) {
      MediaDetailFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.date.now = MediaDetailTestFixtures.laterDate
      $0.mediaStorage.fileExists = { _ in true }
      $0.syncEngine.events = { AsyncStream { $0.finish() } }
    }

    await store.send(.task) {
      $0.now = MediaDetailTestFixtures.laterDate
    }
    await store.receive(.snapshotLoaded(snapshot)) {
      $0.media = snapshot.media
      $0.mediaAuthorName = snapshot.mediaAuthorName
      $0.mediaAuthorColorHex = snapshot.mediaAuthorColorHex
      $0.entries = snapshot.entries
      $0.currentUser = snapshot.currentUser
    }
    await store.receive(.photoCacheReady) { $0.isPhotoCached = true }

    await store.send(.markerTapped(Self.markerTwoNumber)) {
      $0.selectedMarkerNumber = Self.markerTwoNumber
      $0.scrollTargetEntryId = MediaDetailTestFixtures.entryTwoId
    }
    await store.send(.scrollTargetHandled) { $0.scrollTargetEntryId = nil }
    await store.send(.markerSelectionCleared) { $0.selectedMarkerNumber = nil }
  }

  @MainActor
  @Test("Contributor appends entry with markers starting at [3] and queues cloud sync")
  func contributorAddsEntryStartingAtThree() async throws {
    let database = try MediaDetailTestFixtures.seedDatabase(
      activeRole: .contributor,
      isVerifiedMedia: true
    )
    let snapshot = try MediaDetailStore.fetchSnapshot(
      mediaId: MediaDetailTestFixtures.mediaId,
      from: database
    )
    let markerHaptics = LockIsolated(0)
    let successHaptics = LockIsolated(0)
    let outboxCalls = LockIsolated(0)

    let store = makeContributorStore(
      database: database,
      snapshot: snapshot,
      markerHaptics: markerHaptics,
      successHaptics: successHaptics,
      outboxCalls: outboxCalls
    )

    #expect(store.state.canComposeEntry)
    #expect(!store.state.canEditOrHardDeleteEntry(snapshot.entries[0]))
    #expect(!store.state.canRetractEntry(snapshot.entries[0]))

    await store.send(.addEntryTapped) { $0.composer = EntryComposerState() }
    await store.send(.composerToggleMarkerMode) { $0.composer?.isMarkerPlacementMode = true }
    await store.send(.composerTextChanged("Uwaga przy oknie")) {
      $0.composer?.text = "Uwaga przy oknie"
    }
    let draftThree = DetailDraftMarker(
      id: MediaDetailTestFixtures.markerThreeId,
      number: Self.markerThreeNumber,
      x: Self.markerThreeX,
      y: Self.markerThreeY
    )
    await store.send(.composerMarkerAdded(x: Self.markerThreeX, y: Self.markerThreeY)) {
      $0.composer?.markers = [draftThree]
      $0.composer?.text = "Uwaga przy oknie [3]"
      $0.selectedMarkerNumber = Self.markerThreeNumber
    }
    await store.send(.composerSubmitted) { $0.composer?.isSubmitting = true }

    let updated = try MediaDetailStore.fetchSnapshot(
      mediaId: MediaDetailTestFixtures.mediaId,
      from: database
    )
    await store.receive(.composerSucceeded(updated)) {
      $0.composer = nil
      $0.entries = updated.entries
    }
    #expect(updated.entries.count == Self.markerThreeNumber)
    #expect(updated.entries.last?.entry.markers.map(\.number) == [Self.markerThreeNumber])
    #expect(markerHaptics.value == 1 && successHaptics.value == 1 && outboxCalls.value == 1)
  }

  @MainActor
  private func makeContributorStore(
    database: any DatabaseWriter,
    snapshot: MediaDetailSnapshot,
    markerHaptics: LockIsolated<Int>,
    successHaptics: LockIsolated<Int>,
    outboxCalls: LockIsolated<Int>
  ) -> TestStoreOf<MediaDetailFeature> {
    TestStore(
      initialState: MediaDetailFeature.State(
        apartmentId: MediaDetailTestFixtures.apartmentId,
        mediaId: MediaDetailTestFixtures.mediaId,
        media: snapshot.media,
        mediaAuthorName: snapshot.mediaAuthorName,
        mediaAuthorColorHex: snapshot.mediaAuthorColorHex,
        entries: snapshot.entries,
        currentUser: snapshot.currentUser
      )
    ) {
      MediaDetailFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.date.now = MediaDetailTestFixtures.laterDate
      $0.idGenerator = MediaDetailTestFixtures.makeIDGenerator([
        MediaDetailTestFixtures.markerThreeId,
        MediaDetailTestFixtures.entryThreeId,
        MediaDetailTestFixtures.outboxId,
      ])
      $0.haptics.markerDropped = { markerHaptics.withValue { $0 += 1 } }
      $0.haptics.actionSucceeded = { successHaptics.withValue { $0 += 1 } }
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
