import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import SQLiteData
import SyncEngine
import Testing

@testable import MediaDetailFeature

@Suite("MediaDetailFeature Media Deletion Tests")
struct MediaDetailSyncAndMediaDeletionTests {
  @MainActor
  @Test("Local media hard-deletes DB row + disk file and emits delegate")
  func localMediaHardDeleteRemovesFile() async throws {
    let database = try MediaDetailTestFixtures.seedDatabase(
      activeRole: .owner,
      isVerifiedMedia: false
    )
    let deletedFiles = LockIsolated<[String]>([])
    let store = try makeDeleteStore(
      database: database,
      deletedFiles: deletedFiles,
      outboxCalls: nil
    )

    await store.send(.mediaDeleteTapped) { $0.mediaDeleteConfirmation = .hardDeleteLocal }
    await store.send(.mediaDeleteConfirmed)
    await store.receive(.mediaHardDeleteSucceeded) {
      $0.mediaDeleteConfirmation = nil
      $0.pendingHardDeleteDismiss = true
    }
    await store.send(.mediaDeleteSheetDidDismiss) { $0.pendingHardDeleteDismiss = false }
    await store.receive(.delegate(.didDeleteLocalMedia(mediaId: MediaDetailTestFixtures.mediaId)))

    #expect(deletedFiles.value == [MediaDetailTestFixtures.mediaId])
    let remaining = try await database.read {
      try MediaRecord.where { $0.id.eq(MediaDetailTestFixtures.mediaId) }.fetchOne($0)
    }
    #expect(remaining == nil)
  }

  @MainActor
  @Test("Synced media soft-deletes leaving tombstone and views instantiate cleanly")
  func syncedMediaSoftDeleteLeavesTombstone() async throws {
    let database = try MediaDetailTestFixtures.seedDatabase(
      activeRole: .owner,
      isVerifiedMedia: true
    )
    let outboxCalls = LockIsolated(0)
    let store = try makeDeleteStore(database: database, deletedFiles: nil, outboxCalls: outboxCalls)

    await store.send(.mediaDeleteTapped) { $0.mediaDeleteConfirmation = .softDeleteSynced }
    await store.send(.mediaDeleteConfirmed)

    let softDeleted = try MediaDetailStore.fetchSnapshot(
      mediaId: MediaDetailTestFixtures.mediaId,
      from: database
    )
    await store.receive(.mediaSoftDeleteSucceeded(softDeleted)) {
      $0.mediaDeleteConfirmation = nil
      $0.media = softDeleted.media
    }
    #expect(store.state.media?.isSoftDeleted == true)
    #expect(!store.state.canComposeEntry)
    #expect(outboxCalls.value == 1)

    let viewStore = Store(
      initialState: MediaDetailFeature.State(
        apartmentId: MediaDetailTestFixtures.apartmentId,
        mediaId: MediaDetailTestFixtures.mediaId,
        media: softDeleted.media,
        entries: softDeleted.entries,
        currentUser: softDeleted.currentUser
      )
    ) {
      MediaDetailFeature()
    }
    if let media = softDeleted.media {
      _ = (MediaDetailView(store: viewStore), DetailMetadataSheetView(media: media))
    }
  }

  @MainActor
  private func makeDeleteStore(
    database: any DatabaseWriter,
    deletedFiles: LockIsolated<[String]>?,
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
        currentUser: snapshot.currentUser
      )
    ) {
      MediaDetailFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.date.now = MediaDetailTestFixtures.laterDate
      $0.idGenerator = MediaDetailTestFixtures.makeIDGenerator([MediaDetailTestFixtures.outboxId])
      $0.haptics.actionSucceeded = {}
      if let deletedFiles {
        $0.mediaStorage.deleteLocalFile = { id in deletedFiles.withValue { $0.append(id) } }
      }
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
