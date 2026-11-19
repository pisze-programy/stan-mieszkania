import APIClient
import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import SQLiteData
import SyncEngine
import Testing

@testable import ApartmentsListFeature

@Suite("ApartmentsListFeature Sync and Navigation Tests")
struct ApartmentsListFeatureTests {
  private enum Fixtures {
    static let userId = "01933e2a-7b40-7000-8000-000000000001"
    static let apartmentId = "01933e2a-7b40-7000-8000-000000000002"
    static let mediaId = "01933e2a-7b40-7000-8000-000000000003"
    static let outboxId = "01933e2a-7b40-7000-8000-000000000004"
    static let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
    static let width = 1_200
    static let height = 900
    static let bytes = 240_000
    static let sha256 = String(repeating: "a", count: ContractConstants.sha256HexLength)

    static let user = UserProfile(
      id: userId,
      displayName: "Jan Kowalski",
      shortTag: "A1B2",
      color: DomainConstants.defaultAuthorColor,
      createdAt: baseDate
    )

    static let apartment = Apartment(
      id: apartmentId,
      ownerId: userId,
      name: "Kawalerka Mokotów",
      street: "Puławska 10",
      city: "Warszawa",
      role: .owner,
      inviteCode: "K7QM-4XPB",
      createdAt: baseDate,
      updatedAt: baseDate
    )
  }

  private actor SyncCounter {
    var callOrder: [String] = []
    var syncAllCalls = 0
    var outboxCalls = 0

    func recordSyncAll() {
      syncAllCalls += 1
      callOrder.append("syncAllOnEntry")
    }

    func recordOutbox() {
      outboxCalls += 1
      callOrder.append("processOutbox")
    }
  }

  @MainActor
  @Test("Task and pull-to-refresh load SQLiteData snapshot and trigger SyncEngine")
  func syncOnAppearAndPullToRefresh() async throws {
    let database = try seedApartmentWithMedia()
    let counter = SyncCounter()
    let expectedItems = [ApartmentListItem(apartment: Fixtures.apartment, photoCount: 1)]

    let store = TestStore(initialState: ApartmentsListFeature.State()) {
      ApartmentsListFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.syncEngine.events = { AsyncStream { $0.finish() } }
      $0.syncEngine.syncAllOnEntry = {
        await counter.recordSyncAll()
        return 0
      }
      $0.syncEngine.processOutbox = {
        await counter.recordOutbox()
        return SyncOutboxReport(
          processedCount: 0,
          failedCount: 0,
          deferredCount: 0,
          pausedForForceUpdate: false
        )
      }
    }

    await store.send(.task) {
      $0.isSyncing = true
    }
    await store.receive(.localDataLoaded(user: Fixtures.user, items: expectedItems)) {
      $0.currentUser = Fixtures.user
      $0.items = expectedItems
    }
    await store.receive(.syncCompleted(user: Fixtures.user, items: expectedItems)) {
      $0.isSyncing = false
    }

    await store.send(.pulledToRefresh) {
      $0.isSyncing = true
    }
    await store.receive(.localDataLoaded(user: Fixtures.user, items: expectedItems))
    await store.receive(.syncCompleted(user: Fixtures.user, items: expectedItems)) {
      $0.isSyncing = false
    }

    #expect(await counter.syncAllCalls == 2)
    #expect(await counter.outboxCalls == 2)
    #expect(
      await counter.callOrder == [
        "processOutbox",
        "syncAllOnEntry",
        "processOutbox",
        "syncAllOnEntry",
      ]
    )
  }

  private func seedApartmentWithMedia() throws -> any DatabaseWriter {
    let database = try makeInMemoryDatabase()
    let storeHelper = ApartmentMutationStore(database: database)
    try storeHelper.saveLocalUser(Fixtures.user)
    try storeHelper.createApartment(
      Fixtures.apartment,
      creator: ApartmentMember(
        userId: Fixtures.user.id,
        displayName: Fixtures.user.displayName,
        shortTag: Fixtures.user.shortTag,
        color: Fixtures.user.color,
        role: .owner,
        joinedAt: Fixtures.baseDate
      ),
      outboxId: Fixtures.outboxId,
      now: Fixtures.baseDate
    )
    let mediaStore = MediaMutationStore(database: database)
    let localMedia = MediaItem(
      id: Fixtures.mediaId,
      apartmentId: Fixtures.apartmentId,
      authorId: Fixtures.userId,
      kind: .photo,
      source: .camera,
      sha256: Fixtures.sha256,
      capturedAt: Fixtures.baseDate,
      capturedTz: "Europe/Warsaw",
      capturedAtFromImport: false,
      width: Fixtures.width,
      height: Fixtures.height,
      bytes: Fixtures.bytes,
      syncState: .localOnly
    )
    try mediaStore.saveLocalMedia(localMedia, queueForCloud: false, now: Fixtures.baseDate)
    return database
  }

  @MainActor
  @Test("Emits delegate actions for apartment selection and profile tap and instantiates views")
  func delegatesAndViews() async {
    let store = TestStore(
      initialState: ApartmentsListFeature.State(
        currentUser: Fixtures.user,
        items: [ApartmentListItem(apartment: Fixtures.apartment, photoCount: 1)]
      )
    ) {
      ApartmentsListFeature()
    }

    await store.send(.apartmentTapped(Fixtures.apartmentId))
    await store.receive(\.delegate.didSelectApartment)
    await store.send(.profileTapped)
    await store.receive(\.delegate.didTapProfile)

    let viewStore = Store(
      initialState: ApartmentsListFeature.State(
        currentUser: Fixtures.user,
        items: [ApartmentListItem(apartment: Fixtures.apartment, photoCount: 1)]
      )
    ) {
      ApartmentsListFeature()
    }
    let listView = ApartmentsListView(store: viewStore)
    let cardView = ApartmentCardView(
      item: ApartmentListItem(apartment: Fixtures.apartment, photoCount: 1)
    )
    _ = (listView, cardView)
  }
}
