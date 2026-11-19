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

@Suite("ApartmentTimelineFeature Hydration, Author Display, and Sync Recovery Tests")
struct TimelineHydrationAndRecoveryTests {
  private static let expectedSyncCalls = 2

  @MainActor
  @Test("viewDisappeared resets isSyncing and cancels in-flight sync so re-appear syncs again")
  func viewDisappearedResetsSyncStateAndAllowsRestart() async throws {
    let database = try TimelineTestFixtures.seedTimelineDatabase()
    let snapshot = try ApartmentTimelineStore.fetchSnapshot(
      apartmentId: TimelineTestFixtures.apartmentId,
      from: database,
      now: TimelineTestFixtures.thursdayLaterDate,
      calendar: TimelineTestFixtures.warsawCalendar,
      timeZone: TimelineTestFixtures.warsawTimeZone
    )
    let syncCalls = LockIsolated(0)
    let firstSyncGate = AsyncStream<Void>.makeStream()
    let store = makeRecoveryStore(
      database: database,
      syncCalls: syncCalls,
      firstSyncStream: firstSyncGate.stream
    )

    let firstTask = await store.send(.task) {
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
      $0.cloudMediaCount = TimelineTestFixtures.defaultCloudMediaCount
    }

    await store.send(.viewDisappeared) { $0.isSyncing = false }
    firstSyncGate.continuation.finish()
    await firstTask.cancel()

    await store.send(.task) { $0.isSyncing = true }
    await store.receive(.localSnapshotLoaded(snapshot))
    await store.receive(.syncCompleted(snapshot)) { $0.isSyncing = false }
    #expect(syncCalls.value == Self.expectedSyncCalls)
  }

  @MainActor
  private func makeRecoveryStore(
    database: any DatabaseWriter,
    syncCalls: LockIsolated<Int>,
    firstSyncStream: AsyncStream<Void>
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
      $0.syncEngine.processOutbox = {
        SyncOutboxReport(
          processedCount: 0,
          failedCount: 0,
          deferredCount: 0,
          pausedForForceUpdate: false
        )
      }
      $0.syncEngine.syncApartment = { _ in
        let count = syncCalls.withValue { value -> Int in
          value += 1
          return value
        }
        if count == 1 {
          for await _ in firstSyncStream {}
        }
        return 0
      }
    }
  }

  @MainActor
  @Test("Computes showsAuthor and owner delete confirmation copy from distinct authors and members")
  func showsAuthorAndMemberDeleteCopy() throws {
    let singleAuthorDb = try seedSingleOwnerDatabase()
    let singleSnapshot = try ApartmentTimelineStore.fetchSnapshot(
      apartmentId: TimelineTestFixtures.apartmentId,
      from: singleAuthorDb,
      now: TimelineTestFixtures.thursdayLaterDate,
      calendar: TimelineTestFixtures.warsawCalendar,
      timeZone: TimelineTestFixtures.warsawTimeZone
    )
    #expect(!singleSnapshot.showsAuthor)
    #expect(!singleSnapshot.hasOtherMembers)

    let multiAuthorDb = try TimelineTestFixtures.seedTimelineDatabase()
    let multiSnapshot = try ApartmentTimelineStore.fetchSnapshot(
      apartmentId: TimelineTestFixtures.apartmentId,
      from: multiAuthorDb,
      now: TimelineTestFixtures.thursdayLaterDate,
      calendar: TimelineTestFixtures.warsawCalendar,
      timeZone: TimelineTestFixtures.warsawTimeZone
    )
    #expect(multiSnapshot.showsAuthor)
    #expect(multiSnapshot.hasOtherMembers)

    let soloView = ApartmentTimelineView(
      store: Store(
        initialState: ApartmentTimelineFeature.State(
          apartmentId: TimelineTestFixtures.apartmentId,
          apartment: TimelineTestFixtures.makeApartment(role: .owner),
          hasOtherMembers: false,
          leaveConfirmationMode: .ownerDeleteOrLeave
        )
      ) { ApartmentTimelineFeature() }
    )
    let sharedView = ApartmentTimelineView(
      store: Store(
        initialState: ApartmentTimelineFeature.State(
          apartmentId: TimelineTestFixtures.apartmentId,
          apartment: TimelineTestFixtures.makeApartment(role: .owner),
          hasOtherMembers: true,
          leaveConfirmationMode: .ownerDeleteOrLeave
        )
      ) { ApartmentTimelineFeature() }
    )
    #expect(soloView.leaveDialogMessage == L10n.string("apartment.delete.confirmation.message"))
    #expect(
      sharedView.leaveDialogMessage
        == L10n.string("apartment.delete.confirmation.message.transfer")
    )
  }

  private func seedSingleOwnerDatabase() throws -> any DatabaseWriter {
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
      outboxId: TimelineTestFixtures.outboxId,
      now: TimelineTestFixtures.wednesdayDate
    )
    let media = MediaItem(
      id: TimelineTestFixtures.mediaLocalId,
      apartmentId: TimelineTestFixtures.apartmentId,
      authorId: TimelineTestFixtures.ownerId,
      kind: .photo,
      source: .camera,
      sha256: TimelineTestFixtures.sha256,
      capturedAt: TimelineTestFixtures.thursdayDate,
      capturedTz: "Europe/Warsaw",
      capturedAtFromImport: false,
      width: TimelineTestFixtures.width,
      height: TimelineTestFixtures.height,
      bytes: TimelineTestFixtures.bytes,
      syncState: .localOnly
    )
    try MediaMutationStore(database: database).saveLocalMedia(
      media,
      queueForCloud: false,
      now: TimelineTestFixtures.thursdayDate
    )
    return database
  }
}
