import ComposableArchitecture
import Database
import Domain
import Foundation
import SQLiteData
import SyncEngine
import Testing

@testable import ApartmentsListFeature

@Suite("ApartmentsListFeature Sync Events Reactivity Tests")
struct ApartmentsListSyncEventsTests {
  private enum Fixtures {
    static let userId = "01933e2a-7b40-7000-8000-000000000001"
    static let apartmentId = "01933e2a-7b40-7000-8000-000000000002"
    static let firstMediaId = "01933e2a-7b40-7000-8000-000000000003"
    static let secondMediaId = "01933e2a-7b40-7000-8000-000000000099"
    static let outboxId = "01933e2a-7b40-7000-8000-000000000004"
    static let baseTimestamp: TimeInterval = 1_700_000_000
    static let baseDate = Date(timeIntervalSince1970: baseTimestamp)
    static let width = 1_200
    static let height = 900
    static let bytes = 240_000
    static let updatedPhotoCount = 2
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

  @MainActor
  @Test("Reacts to syncEngine.events() stream by reloading SQLiteData photo counts")
  func reactsToSyncEngineEvents() async throws {
    let database = try seedInitialDatabase()
    let (stream, continuation) = AsyncStream.makeStream(of: SyncEvent.self)
    let initialItems = [ApartmentListItem(apartment: Fixtures.apartment, photoCount: 1)]

    let store = TestStore(initialState: ApartmentsListFeature.State()) {
      ApartmentsListFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.syncEngine.events = { stream }
      $0.syncEngine.syncAllOnEntry = { 0 }
      $0.syncEngine.processOutbox = {
        SyncOutboxReport(
          processedCount: 0,
          failedCount: 0,
          deferredCount: 0,
          pausedForForceUpdate: false
        )
      }
    }

    let task = await store.send(.task) {
      $0.isSyncing = true
    }
    await store.receive(.localDataLoaded(user: Fixtures.user, items: initialItems)) {
      $0.currentUser = Fixtures.user
      $0.items = initialItems
    }
    await store.receive(.syncCompleted(user: Fixtures.user, items: initialItems)) {
      $0.isSyncing = false
    }

    try insertMedia(id: Fixtures.secondMediaId, into: database)
    let updatedItems = [
      ApartmentListItem(apartment: Fixtures.apartment, photoCount: Fixtures.updatedPhotoCount)
    ]
    let syncEvent = SyncEvent.apartmentSynced(
      apartmentId: Fixtures.apartmentId,
      appliedChangesCount: 1
    )
    continuation.yield(syncEvent)
    await store.receive(.syncEventReceived(syncEvent))
    await store.receive(.localDataLoaded(user: Fixtures.user, items: updatedItems)) {
      $0.items = updatedItems
    }

    continuation.finish()
    await task.cancel()
  }

  private func seedInitialDatabase() throws -> any DatabaseWriter {
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
    try insertMedia(id: Fixtures.firstMediaId, into: database)
    return database
  }

  private func insertMedia(id: String, into database: any DatabaseWriter) throws {
    let media = MediaItem(
      id: id,
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
    try MediaMutationStore(database: database).saveLocalMedia(
      media,
      queueForCloud: false,
      now: Fixtures.baseDate
    )
  }
}
