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

  private static let progressEvent = SyncEvent.uploadProgress(
    mediaId: TimelineTestFixtures.mediaLocalId,
    fractionCompleted: halfProgress
  )
  private static let otherQuotaEvent = SyncEvent.quotaExceeded(
    apartmentId: TimelineTestFixtures.otherApartmentId,
    mediaId: TimelineTestFixtures.mediaLocalId
  )
  private static let apartmentQuotaEvent = SyncEvent.quotaExceeded(
    apartmentId: TimelineTestFixtures.apartmentId,
    mediaId: TimelineTestFixtures.mediaLocalId
  )

  @MainActor
  @Test("SyncEvent stream tracks upload progress and auto-dismisses quota toast after 4 seconds")
  func quotaExceededEventStreamAutoDismisses() async throws {
    let clock = TestClock()
    let database = try TimelineTestFixtures.seedTimelineDatabase()
    let warningHaptics = LockIsolated(0)
    let (stream, continuation) = AsyncStream.makeStream(of: SyncEvent.self)
    let snapshot = try ApartmentTimelineStore.fetchSnapshot(
      apartmentId: TimelineTestFixtures.apartmentId, from: database,
      now: TimelineTestFixtures.thursdayLaterDate,
      calendar: TimelineTestFixtures.warsawCalendar, timeZone: TimelineTestFixtures.warsawTimeZone
    )
    let store = makeStreamStore(
      database: database, clock: clock, stream: stream, warningHaptics: warningHaptics
    )

    let taskEffect = await store.send(.task) {
      $0.now = TimelineTestFixtures.thursdayLaterDate
      $0.isSyncing = true
    }
    await store.receive(.localSnapshotLoaded(snapshot)) {
      $0.apartment = snapshot.apartment
      $0.sections = snapshot.sections
      $0.hasLoadedLocalSnapshot = true
      $0.showsAuthor = true
      $0.hasOtherMembers = true
      $0.localUnsyncedCount = 1
      $0.cloudMediaCount = Self.expectedCloudCount
    }
    await store.receive(.syncCompleted(snapshot)) { $0.isSyncing = false }

    continuation.yield(Self.progressEvent)
    await store.receive(.syncEventReceived(Self.progressEvent)) {
      $0.uploadProgressByMediaId[TimelineTestFixtures.mediaLocalId] = Self.halfProgress
    }
    continuation.yield(Self.otherQuotaEvent)
    await store.receive(.syncEventReceived(Self.otherQuotaEvent))

    continuation.yield(Self.apartmentQuotaEvent)
    await store.receive(.syncEventReceived(Self.apartmentQuotaEvent)) {
      $0.uploadProgressByMediaId[TimelineTestFixtures.mediaLocalId] = nil
      $0.quotaNoticeMessage = L10n.string("media.summary.quota.notice")
    }
    await store.receive(.localSnapshotLoaded(snapshot))
    await clock.advance(by: ApartmentTimelineConstants.quotaToastAutoDismissDelay)
    await store.receive(.dismissQuotaNotice) { $0.quotaNoticeMessage = nil }
    continuation.finish()
    await taskEffect.cancel()
    #expect(warningHaptics.value == 1)
  }

  @MainActor
  private func makeStreamStore(
    database: any DatabaseWriter,
    clock: TestClock<Duration>,
    stream: AsyncStream<SyncEvent>,
    warningHaptics: LockIsolated<Int>
  ) -> TestStoreOf<ApartmentTimelineFeature> {
    TestStore(
      initialState: ApartmentTimelineFeature.State(apartmentId: TimelineTestFixtures.apartmentId)
    ) {
      ApartmentTimelineFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.continuousClock = clock
      $0.date.now = TimelineTestFixtures.thursdayLaterDate
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
