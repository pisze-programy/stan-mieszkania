import AppConfigClient
import ComposableArchitecture
import Database
import Domain
import Foundation
import SQLiteData
import SyncEngine
import Testing

@testable import ApartmentTimelineFeature

@Suite("ApartmentTimelineFeature Offline Sync Order and Timezone Grouping Tests")
struct TimelineOfflineSyncAndTimezoneTests {
  // 2022-11-16T23:30:00Z -> 2022-11-17T00:30:00+01:00 in Europe/Warsaw ("17 listopada, czwartek")
  private static let midnightCrossUtcEpoch: TimeInterval = 1_668_641_400
  private static let midnightCrossDate = Date(timeIntervalSince1970: midnightCrossUtcEpoch)
  private static let pendingCreateOutboxId = "01933e2a-7b40-7000-8000-000000000901"

  @MainActor
  @Test("Flushes pending createApartment outbox op before calling syncApartment")
  func offlineCreatedApartmentFlushesOutboxBeforeSync() async throws {
    let database = try seedOfflineCreatedApartment()
    let callOrder = LockIsolated<[String]>([])
    let outboxFlushed = LockIsolated(false)
    let expectedSnapshot = try ApartmentTimelineStore.fetchSnapshot(
      apartmentId: TimelineTestFixtures.apartmentId,
      from: database,
      calendar: TimelineTestFixtures.warsawCalendar,
      timeZone: TimelineTestFixtures.warsawTimeZone
    )

    let store = makeOfflineSyncStore(
      database: database,
      callOrder: callOrder,
      outboxFlushed: outboxFlushed
    )

    await store.send(.task) { $0.isSyncing = true }
    await store.receive(.localSnapshotLoaded(expectedSnapshot)) {
      $0.apartment = expectedSnapshot.apartment
    }
    await store.receive(.syncCompleted(expectedSnapshot)) {
      $0.isSyncing = false
    }

    #expect(callOrder.value == ["processOutbox", "syncApartment"])
    #expect(store.state.errorMessage == nil)
  }

  @Test("Synchronizes calendar timeZone with display timeZone across midnight boundaries")
  func synchronizesGroupingCalendarWithTimeZone() throws {
    let database = try makeInMemoryDatabase()
    try ApartmentMutationStore(database: database).saveLocalUser(TimelineTestFixtures.ownerUser)
    let apartment = TimelineTestFixtures.makeApartment(role: .owner, cloudMediaCount: 0)
    try database.write { db in
      try ApartmentRecord.insert { ApartmentRecord(apartment: apartment) }.execute(db)
    }
    let midnightPhoto = MediaItem(
      id: TimelineTestFixtures.mediaLocalId,
      apartmentId: TimelineTestFixtures.apartmentId,
      authorId: TimelineTestFixtures.ownerId,
      kind: .photo,
      source: .camera,
      sha256: TimelineTestFixtures.sha256,
      capturedAt: Self.midnightCrossDate,
      capturedTz: "Europe/Warsaw",
      capturedAtFromImport: false,
      width: TimelineTestFixtures.width,
      height: TimelineTestFixtures.height,
      bytes: TimelineTestFixtures.bytes,
      syncState: .localOnly
    )
    try MediaMutationStore(database: database).saveLocalMedia(
      midnightPhoto,
      queueForCloud: false,
      now: Self.midnightCrossDate
    )

    var utcCalendar = Calendar(identifier: .gregorian)
    utcCalendar.timeZone = .gmt
    let snapshot = try ApartmentTimelineStore.fetchSnapshot(
      apartmentId: TimelineTestFixtures.apartmentId,
      from: database,
      calendar: utcCalendar,
      timeZone: TimelineTestFixtures.warsawTimeZone
    )

    #expect(snapshot.sections.count == 1)
    #expect(snapshot.sections[0].dayKey == "2022-11-17")
    #expect(snapshot.sections[0].title == "17 listopada, czwartek")
  }

  private func seedOfflineCreatedApartment() throws -> any DatabaseWriter {
    let database = try makeInMemoryDatabase()
    let aptStore = ApartmentMutationStore(database: database)
    try aptStore.saveLocalUser(TimelineTestFixtures.ownerUser)
    let apartment = TimelineTestFixtures.makeApartment(role: .owner, cloudMediaCount: 0)
    let creator = ApartmentMember(
      userId: TimelineTestFixtures.ownerUser.id,
      displayName: TimelineTestFixtures.ownerUser.displayName,
      shortTag: TimelineTestFixtures.ownerUser.shortTag,
      color: TimelineTestFixtures.ownerUser.color,
      role: .owner,
      joinedAt: TimelineTestFixtures.wednesdayDate
    )
    try aptStore.createApartment(
      apartment,
      creator: creator,
      outboxId: Self.pendingCreateOutboxId,
      now: TimelineTestFixtures.wednesdayDate
    )
    return database
  }

  @MainActor
  private func makeOfflineSyncStore(
    database: any DatabaseWriter,
    callOrder: LockIsolated<[String]>,
    outboxFlushed: LockIsolated<Bool>
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
      $0.syncEngine.events = { AsyncStream { $0.finish() } }
      $0.syncEngine.processOutbox = {
        callOrder.withValue { $0.append("processOutbox") }
        try? OutboxRepository(database: database).markSucceeded(id: Self.pendingCreateOutboxId)
        outboxFlushed.setValue(true)
        return SyncOutboxReport(
          processedCount: 1,
          failedCount: 0,
          deferredCount: 0,
          pausedForForceUpdate: false
        )
      }
      $0.syncEngine.syncApartment = { _ in
        callOrder.withValue { $0.append("syncApartment") }
        #expect(outboxFlushed.value)
        return 0
      }
    }
  }
}
