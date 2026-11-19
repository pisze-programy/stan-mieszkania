import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import SyncEngine
import Testing

@testable import ApartmentsListFeature

@Suite("ApartmentsListFeature Create Tests")
struct ApartmentsListCreateTests {
  private enum Fixtures {
    static let userId = "01933e2a-7b40-7000-8000-000000000001"
    static let createdApartmentId = "01933e2a-7b40-7000-8000-000000000002"
    static let outboxId = "01933e2a-7b40-7000-8000-000000000003"
    static let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    static let user = UserProfile(
      id: userId,
      displayName: "Jan Kowalski",
      shortTag: "A1B2",
      color: DomainConstants.defaultAuthorColor,
      createdAt: baseDate
    )

    static let createdApartment = Apartment(
      id: createdApartmentId,
      ownerId: userId,
      name: "Apartament Centrum",
      street: "Marszałkowska 1",
      city: "Warszawa",
      role: .owner,
      createdAt: baseDate,
      updatedAt: baseDate
    )
  }

  private actor OutboxRecorder {
    var outboxTriggers = 0

    func recordOutbox() { outboxTriggers += 1 }
  }

  @MainActor
  @Test("Validates and creates apartment offline with outbox sync trigger")
  func createApartmentOffline() async throws {
    let database = try makeInMemoryDatabase()
    try ApartmentMutationStore(database: database).saveLocalUser(Fixtures.user)
    let recorder = OutboxRecorder()
    let ids = LockIsolated([Fixtures.createdApartmentId, Fixtures.outboxId])

    let store = TestStore(initialState: ApartmentsListFeature.State()) {
      ApartmentsListFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.date.now = Fixtures.baseDate
      $0.idGenerator = ClosureIDGenerator {
        ids.withValue { $0.removeFirst() }
      }
      $0.syncEngine.processOutbox = {
        await recorder.recordOutbox()
        return SyncOutboxReport(
          processedCount: 0,
          failedCount: 1,
          deferredCount: 0,
          pausedForForceUpdate: false
        )
      }
    }

    await store.send(.createMenuTapped) {
      $0.createSheet = ApartmentsListFeature.CreateApartmentSheetState()
    }
    await store.send(.createSubmitted) {
      $0.createSheet?.errorMessage = L10n.errorMessage(for: .apartmentValidationFailed)
    }

    await store.send(.createNameChanged("Apartament Centrum")) {
      $0.createSheet?.name = "Apartament Centrum"
      $0.createSheet?.errorMessage = nil
    }
    await store.send(.createStreetChanged("Marszałkowska 1")) {
      $0.createSheet?.street = "Marszałkowska 1"
    }
    await store.send(.createCityChanged("Warszawa")) {
      $0.createSheet?.city = "Warszawa"
    }
    await store.send(.createSubmitted) {
      $0.createSheet?.isSaving = true
    }

    await store.receive(\.createSucceeded) {
      $0.createSheet = nil
      $0.currentUser = Fixtures.user
      $0.items = [ApartmentListItem(apartment: Fixtures.createdApartment, photoCount: 0)]
    }

    #expect(await recorder.outboxTriggers == 1)
    let pending = try OutboxRepository(database: database).fetchAllOperations()
    #expect(pending.count == 1)
    #expect(pending.first?.operationType == OutboxOperationType.createApartment.rawValue)
  }
}
