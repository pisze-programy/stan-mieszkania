import AppConfigClient
import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import SQLiteData
import SyncEngine
import Testing

@testable import ApartmentTimelineFeature

@Suite("ApartmentTimelineFeature Quota and Stream Event Tests")
struct TimelineQuotaAndEventsTests {
  private static let emptyReport = SyncOutboxReport(
    processedCount: 0,
    failedCount: 0,
    deferredCount: 0,
    pausedForForceUpdate: false
  )
  private static let expectedCloudCount = 2
  private static let halfProgress = 0.5

  @MainActor
  @Test("SyncEvent stream surfaces QUOTA_EXCEEDED alert and tracks upload progress")
  func quotaExceededEventStream() async throws {
    let database = try TimelineTestFixtures.seedTimelineDatabase()
    let warningHaptics = LockIsolated(0)
    let (stream, continuation) = AsyncStream.makeStream(of: SyncEvent.self)
    let snapshot = try ApartmentTimelineStore.fetchSnapshot(
      apartmentId: TimelineTestFixtures.apartmentId,
      from: database,
      calendar: TimelineTestFixtures.warsawCalendar,
      timeZone: TimelineTestFixtures.warsawTimeZone
    )
    let store = makeStreamStore(
      database: database,
      stream: stream,
      warningHaptics: warningHaptics
    )

    let taskEffect = await store.send(.task) { $0.isSyncing = true }
    await store.receive(.localSnapshotLoaded(snapshot)) {
      $0.apartment = snapshot.apartment
      $0.sections = snapshot.sections
      $0.localUnsyncedCount = 1
      $0.cloudMediaCount = Self.expectedCloudCount
    }
    await store.receive(.syncCompleted(snapshot)) { $0.isSyncing = false }

    let progressEvent = SyncEvent.uploadProgress(
      mediaId: TimelineTestFixtures.mediaLocalId,
      fractionCompleted: Self.halfProgress
    )
    continuation.yield(progressEvent)
    await store.receive(.syncEventReceived(progressEvent)) {
      $0.uploadProgressByMediaId[TimelineTestFixtures.mediaLocalId] = Self.halfProgress
    }

    let otherQuota = SyncEvent.quotaExceeded(
      apartmentId: TimelineTestFixtures.otherApartmentId,
      mediaId: TimelineTestFixtures.mediaLocalId
    )
    continuation.yield(otherQuota)
    await store.receive(.syncEventReceived(otherQuota))

    let apartmentQuota = SyncEvent.quotaExceeded(
      apartmentId: TimelineTestFixtures.apartmentId,
      mediaId: TimelineTestFixtures.mediaLocalId
    )
    continuation.yield(apartmentQuota)
    await store.receive(.syncEventReceived(apartmentQuota)) {
      $0.uploadProgressByMediaId[TimelineTestFixtures.mediaLocalId] = nil
      $0.quotaNoticeMessage = L10n.string("media.summary.quota.notice")
    }
    await store.receive(.localSnapshotLoaded(snapshot))
    await store.send(.dismissQuotaNotice) { $0.quotaNoticeMessage = nil }

    continuation.finish()
    await taskEffect.cancel()
    #expect(warningHaptics.value == 1)
  }

  @MainActor
  private func makeStreamStore(
    database: any DatabaseWriter,
    stream: AsyncStream<SyncEvent>,
    warningHaptics: LockIsolated<Int>
  ) -> TestStoreOf<ApartmentTimelineFeature> {
    TestStore(
      initialState: ApartmentTimelineFeature.State(apartmentId: TimelineTestFixtures.apartmentId)
    ) {
      ApartmentTimelineFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.calendar = TimelineTestFixtures.warsawCalendar
      $0.timeZone = TimelineTestFixtures.warsawTimeZone
      $0.appConfigClient.loadCachedOrDefault = { .fallbackDefaults }
      $0.syncEngine.events = { stream }
      $0.syncEngine.syncApartment = { _ in 0 }
      $0.syncEngine.processOutbox = { Self.emptyReport }
      $0.haptics.warning = { warningHaptics.withValue { $0 += 1 } }
    }
  }
}
