import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import SQLiteData
import SyncEngine
import Testing

@testable import MediaDetailFeature

@Suite("MediaDetailFeature Upload and Quota Tests")
struct MediaDetailUploadAndQuotaTests {
  @MainActor
  @Test("Manual single-photo upload queues media and QUOTA_EXCEEDED event alerts user safely")
  func singlePhotoUploadAndQuotaNotice() async throws {
    let database = try MediaDetailTestFixtures.seedDatabase(
      activeRole: .owner,
      isVerifiedMedia: false
    )
    let snapshot = try MediaDetailStore.fetchSnapshot(
      mediaId: MediaDetailTestFixtures.mediaId,
      from: database
    )
    let (stream, continuation) = AsyncStream.makeStream(of: SyncEvent.self)
    let enqueuedIds = LockIsolated<[String]>([])
    let warningHaptics = LockIsolated(0)
    let store = makeUploadStore(
      database: database,
      stream: stream,
      enqueuedIds: enqueuedIds,
      warningHaptics: warningHaptics
    )

    let taskEffect = await store.send(.task) { $0.now = MediaDetailTestFixtures.laterDate }
    await store.receive(.snapshotLoaded(snapshot)) {
      $0.media = snapshot.media
      $0.mediaAuthorName = snapshot.mediaAuthorName
      $0.mediaAuthorColorHex = snapshot.mediaAuthorColorHex
      $0.entries = snapshot.entries
      $0.currentUser = snapshot.currentUser
    }
    await store.receive(.photoCacheReady) { $0.isPhotoCached = true }

    await store.send(.uploadToCloudTapped) { $0.isUploadingToCloud = true }
    let queued = try MediaDetailStore.fetchSnapshot(
      mediaId: MediaDetailTestFixtures.mediaId,
      from: database
    )
    await store.receive(.uploadToCloudFinished(queued)) {
      $0.isUploadingToCloud = false
      $0.media = queued.media
    }

    let quotaEvent = SyncEvent.quotaExceeded(
      apartmentId: MediaDetailTestFixtures.apartmentId,
      mediaId: MediaDetailTestFixtures.mediaId
    )
    continuation.yield(quotaEvent)
    await store.receive(.syncEventReceived(quotaEvent)) {
      $0.quotaNoticeMessage = L10n.string("media.summary.quota.notice")
    }
    await store.receive(.snapshotLoaded(queued))
    continuation.finish()
    await taskEffect.cancel()
    #expect(enqueuedIds.value == [MediaDetailTestFixtures.mediaId] && warningHaptics.value == 1)
  }

  @MainActor
  private func makeUploadStore(
    database: any DatabaseWriter,
    stream: AsyncStream<SyncEvent>,
    enqueuedIds: LockIsolated<[String]>,
    warningHaptics: LockIsolated<Int>
  ) -> TestStoreOf<MediaDetailFeature> {
    TestStore(
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
      $0.syncEngine.events = { stream }
      $0.syncEngine.enqueueMediaUpload = { id in
        enqueuedIds.withValue { $0.append(id) }
        try MediaMutationStore(database: database).queueLocalMediaForCloud(
          mediaId: id,
          now: MediaDetailTestFixtures.laterDate
        )
      }
      $0.syncEngine.processOutbox = {
        SyncOutboxReport(
          processedCount: 1,
          failedCount: 0,
          deferredCount: 0,
          pausedForForceUpdate: false
        )
      }
      $0.haptics.actionSucceeded = {}
      $0.haptics.warning = { warningHaptics.withValue { $0 += 1 } }
    }
  }
}
