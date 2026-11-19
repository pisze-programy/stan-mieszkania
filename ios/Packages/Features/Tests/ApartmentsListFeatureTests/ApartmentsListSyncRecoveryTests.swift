import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import SQLiteData
import SyncEngine
import Testing

@testable import ApartmentsListFeature

@Suite("ApartmentsListFeature Self-Healing Sync Recovery Tests")
struct ApartmentsListSyncRecoveryTests {
  private enum Fixtures {
    static let userId = "01933e2a-7b40-7000-8000-000000000091"
    static let apartmentId = "01933e2a-7b40-7000-8000-000000000092"
    static let outboxId = "01933e2a-7b40-7000-8000-000000000093"
    static let baseEpoch: TimeInterval = 1_700_000_000
    static let baseDate = Date(timeIntervalSince1970: baseEpoch)
    static let expectedSyncCount = 2

    static let user = UserProfile(
      id: userId,
      displayName: "Jan Kowalski",
      shortTag: "A1B2",
      color: "#007AFF",
      createdAt: baseDate
    )

    static let apartment = Apartment(
      id: apartmentId,
      ownerId: userId,
      name: "Kawalerka Mokotów",
      street: "Puławska 10",
      city: "Warszawa",
      role: .owner,
      createdAt: baseDate,
      updatedAt: baseDate
    )
  }

  @MainActor
  @Test("viewDisappeared resets isSyncing and cancels in-flight sync so re-appear syncs again")
  func viewDisappearedResetsSyncStateAndAllowsRestart() async throws {
    let database = try seedDatabase()
    let syncCalls = LockIsolated(0)
    let firstSyncGate = AsyncStream<Void>.makeStream()
    let expectedItems = [ApartmentListItem(apartment: Fixtures.apartment, photoCount: 0)]
    let store = makeRecoveryStore(
      database: database,
      syncCalls: syncCalls,
      firstSyncStream: firstSyncGate.stream
    )

    let firstTask = await store.send(.task) { $0.isSyncing = true }
    await store.receive(.localDataLoaded(user: Fixtures.user, items: expectedItems)) {
      $0.currentUser = Fixtures.user
      $0.items = expectedItems
    }

    await store.send(.viewDisappeared) { $0.isSyncing = false }
    firstSyncGate.continuation.finish()
    await firstTask.cancel()

    await store.send(.task) { $0.isSyncing = true }
    await store.receive(.localDataLoaded(user: Fixtures.user, items: expectedItems))
    await store.receive(.syncCompleted(user: Fixtures.user, items: expectedItems)) {
      $0.isSyncing = false
    }

    #expect(syncCalls.value == Fixtures.expectedSyncCount)
    _ = PressableCardButtonStyle()
  }

  private func seedDatabase() throws -> any DatabaseWriter {
    let database = try makeInMemoryDatabase()
    let storeHelper = ApartmentMutationStore(database: database)
    try storeHelper.saveLocalUser(Fixtures.user)
    let creator = ApartmentMember(
      userId: Fixtures.user.id,
      displayName: Fixtures.user.displayName,
      shortTag: Fixtures.user.shortTag,
      color: Fixtures.user.color,
      role: .owner,
      joinedAt: Fixtures.baseDate
    )
    try storeHelper.createApartment(
      Fixtures.apartment,
      creator: creator,
      outboxId: Fixtures.outboxId,
      now: Fixtures.baseDate
    )
    return database
  }

  @MainActor
  private func makeRecoveryStore(
    database: any DatabaseWriter,
    syncCalls: LockIsolated<Int>,
    firstSyncStream: AsyncStream<Void>
  ) -> TestStoreOf<ApartmentsListFeature> {
    TestStore(initialState: ApartmentsListFeature.State()) {
      ApartmentsListFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.syncEngine.events = { AsyncStream { $0.finish() } }
      $0.syncEngine.processOutbox = {
        SyncOutboxReport(
          processedCount: 0,
          failedCount: 0,
          deferredCount: 0,
          pausedForForceUpdate: false
        )
      }
      $0.syncEngine.syncAllOnEntry = {
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
}
