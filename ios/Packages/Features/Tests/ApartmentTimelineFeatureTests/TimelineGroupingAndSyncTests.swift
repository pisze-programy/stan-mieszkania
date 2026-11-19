import AppConfigClient
import ComposableArchitecture
import Database
import Domain
import Foundation
import SQLiteData
import SyncEngine
import Testing

@testable import ApartmentTimelineFeature

@Suite("ApartmentTimelineFeature Grouping and Sync Tests")
struct TimelineGroupingAndSyncTests {
  private actor CallCounter {
    var syncApartmentCalls: [String] = []
    var enqueueAllCalls: [String] = []
    var outboxCalls = 0

    func recordSync(_ id: String) { syncApartmentCalls.append(id) }
    func recordEnqueueAll(_ id: String) { enqueueAllCalls.append(id) }
    func recordOutbox() { outboxCalls += 1 }
  }

  private static let emptyReport = SyncOutboxReport(
    processedCount: 0,
    failedCount: 0,
    deferredCount: 0,
    pausedForForceUpdate: false
  )
  private static let twoCount = 2

  @Test("Groups media descending by Polish day headers and computes local/cloud counts")
  func polishDayGroupingAndCounts() throws {
    let database = try TimelineTestFixtures.seedTimelineDatabase()
    let snapshot = try fetchSnapshot(from: database)

    #expect(snapshot.sections.count == Self.twoCount)
    #expect(snapshot.sections[0].title == "17 listopada, Czwartek")
    #expect(snapshot.sections[0].items.count == Self.twoCount)
    #expect(snapshot.sections[0].items[0].id == TimelineTestFixtures.mediaLocalId)
    #expect(snapshot.sections[0].items[1].id == TimelineTestFixtures.mediaVerifiedId)
    #expect(snapshot.sections[1].title == "16 listopada, Środa")
    #expect(snapshot.sections[1].items.count == 1)
    #expect(snapshot.sections[1].items[0].media.isSoftDeleted)
    #expect(snapshot.localUnsyncedCount == 1)
    #expect(snapshot.cloudMediaCount == Self.twoCount)
  }

  @MainActor
  @Test("Syncs apartment and processes outbox on appear and pull-to-refresh")
  func syncOnAppearAndPullToRefresh() async throws {
    let database = try TimelineTestFixtures.seedTimelineDatabase()
    let counter = CallCounter()
    let snapshot = try fetchSnapshot(from: database)
    let store = makeSyncStore(database: database, counter: counter)

    await store.send(.task) {
      $0.now = TimelineTestFixtures.thursdayLaterDate
      $0.isSyncing = true
      $0.quotaLimit = ContractConstants.defaultCloudMediaQuotaPerApartment
    }
    await store.receive(.localSnapshotLoaded(snapshot)) {
      $0.apartment = snapshot.apartment
      $0.sections = snapshot.sections
      $0.hasLoadedLocalSnapshot = true
      $0.showsAuthor = true
      $0.hasOtherMembers = true
      $0.localUnsyncedCount = 1
      $0.cloudMediaCount = Self.twoCount
    }
    await store.receive(.syncCompleted(snapshot)) { $0.isSyncing = false }

    await store.send(.pulledToRefresh) { $0.isSyncing = true }
    await store.receive(.localSnapshotLoaded(snapshot))
    await store.receive(.syncCompleted(snapshot)) { $0.isSyncing = false }

    #expect(await counter.syncApartmentCalls.count == Self.twoCount)
    #expect(await counter.outboxCalls == Self.twoCount)
  }

  @MainActor
  @Test("Manual Sync All enqueues all local media, flushes outbox, and refreshes counts")
  func manualSyncAllLocalMedia() async throws {
    let database = try TimelineTestFixtures.seedTimelineDatabase()
    let counter = CallCounter()
    let successHaptics = LockIsolated(0)
    let initial = try fetchSnapshot(from: database)
    let store = makeSyncAllStore(
      database: database,
      initial: initial,
      counter: counter,
      successHaptics: successHaptics
    )

    await store.send(.syncAllLocalTapped) { $0.isSyncingAllLocal = true }
    let updated = try fetchSnapshot(from: database)
    #expect(updated.localUnsyncedCount == 0)
    await store.receive(.syncAllLocalCompleted(updated)) {
      $0.isSyncingAllLocal = false
      $0.sections = updated.sections
      $0.hasLoadedLocalSnapshot = true
      $0.showsAuthor = true
      $0.hasOtherMembers = true
      $0.localUnsyncedCount = 0
    }

    #expect(await counter.enqueueAllCalls == [TimelineTestFixtures.apartmentId])
    #expect(await counter.outboxCalls == 1)
    #expect(successHaptics.value == 1)
  }

  private func fetchSnapshot(from db: any DatabaseWriter) throws -> ApartmentTimelineSnapshot {
    try ApartmentTimelineStore.fetchSnapshot(
      apartmentId: TimelineTestFixtures.apartmentId,
      from: db,
      now: TimelineTestFixtures.thursdayLaterDate,
      calendar: TimelineTestFixtures.warsawCalendar,
      timeZone: TimelineTestFixtures.warsawTimeZone
    )
  }

  @MainActor
  private func makeSyncStore(
    database: any DatabaseWriter,
    counter: CallCounter
  ) -> TestStoreOf<ApartmentTimelineFeature> {
    TestStore(
      initialState: ApartmentTimelineFeature.State(apartmentId: TimelineTestFixtures.apartmentId)
    ) {
      ApartmentTimelineFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.date.now = TimelineTestFixtures.thursdayLaterDate
      $0.calendar = TimelineTestFixtures.warsawCalendar
      $0.timeZone = TimelineTestFixtures.warsawTimeZone
      $0.appConfigClient.loadCachedOrDefault = { .fallbackDefaults }
      $0.syncEngine.events = { AsyncStream { $0.finish() } }
      $0.syncEngine.syncApartment = { id in
        await counter.recordSync(id)
        return 0
      }
      $0.syncEngine.processOutbox = {
        await counter.recordOutbox()
        return Self.emptyReport
      }
    }
  }

  @MainActor
  private func makeSyncAllStore(
    database: any DatabaseWriter,
    initial: ApartmentTimelineSnapshot,
    counter: CallCounter,
    successHaptics: LockIsolated<Int>
  ) -> TestStoreOf<ApartmentTimelineFeature> {
    TestStore(
      initialState: ApartmentTimelineFeature.State(
        apartmentId: TimelineTestFixtures.apartmentId,
        apartment: initial.apartment,
        sections: initial.sections,
        localUnsyncedCount: initial.localUnsyncedCount,
        cloudMediaCount: initial.cloudMediaCount
      )
    ) {
      ApartmentTimelineFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.date.now = TimelineTestFixtures.thursdayLaterDate
      $0.calendar = TimelineTestFixtures.warsawCalendar
      $0.timeZone = TimelineTestFixtures.warsawTimeZone
      $0.syncEngine.enqueueAllLocalMedia = { id in
        await counter.recordEnqueueAll(id)
        let mediaStore = MediaMutationStore(database: database)
        try mediaStore.queueLocalMediaForCloud(
          mediaId: TimelineTestFixtures.mediaLocalId,
          now: TimelineTestFixtures.thursdayLaterDate
        )
        return 1
      }
      $0.syncEngine.processOutbox = {
        await counter.recordOutbox()
        return Self.emptyReport
      }
      $0.haptics.actionSucceeded = { successHaptics.withValue { $0 += 1 } }
    }
  }
}
