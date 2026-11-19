import Database
import Domain
import Foundation
import SQLiteData
import Testing

@Suite("Apartment Metadata S2-8 and Outbox Queue Tests")
struct ApartmentAndOutboxTests {
  @Test("Creating and editing apartment metadata automatically enqueues outbox operations")
  func apartmentCreateAndEditAlwaysEnqueueOutbox() throws {
    let database = try makeInMemoryDatabase()
    let apartmentStore = ApartmentMutationStore(database: database)
    let outbox = OutboxRepository(database: database)

    try apartmentStore.createApartment(
      DatabaseTestFixtures.makeApartment(),
      creator: DatabaseTestFixtures.makeOwnerMember(),
      outboxId: DatabaseTestFixtures.outboxOneId,
      now: DatabaseTestFixtures.baseDate
    )

    let updated = try apartmentStore.updateApartmentMetadata(
      ApartmentMetadataUpdate(
        apartmentId: DatabaseTestFixtures.apartmentId,
        name: "Mieszkanie Srodmiescie",
        street: "Marszalkowska 5",
        city: "Warszawa",
        authorId: DatabaseTestFixtures.ownerId
      ),
      outboxId: DatabaseTestFixtures.outboxTwoId,
      now: DatabaseTestFixtures.plusOneMinute
    )

    #expect(updated.name == "Mieszkanie Srodmiescie")
    #expect(updated.street == "Marszalkowska 5")

    let operations = try outbox.fetchRunnableOperations(asOf: DatabaseTestFixtures.plusOneMinute)
    #expect(operations.count == DatabaseTestFixtures.expectedCountTwo)
    #expect(operations[0].id == DatabaseTestFixtures.outboxOneId)
    #expect(operations[0].operationType == OutboxOperationType.createApartment.rawValue)
    #expect(operations[1].id == DatabaseTestFixtures.outboxTwoId)
    #expect(operations[1].operationType == OutboxOperationType.updateApartment.rawValue)

    let updatePayload = try operations[1].decodePayload(UpdateApartmentOutboxPayload.self)
    #expect(updatePayload.name == "Mieszkanie Srodmiescie")
    #expect(updatePayload.street == "Marszalkowska 5")
    #expect(updatePayload.city == "Warszawa")

    let changes = try database.read { db in
      try ApartmentChangeRecord
        .where { $0.apartmentId.eq(DatabaseTestFixtures.apartmentId) }
        .fetchAll(db)
    }
    #expect(changes.count == DatabaseTestFixtures.expectedCountTwo)
    #expect(
      Set(changes.map(\.field)) == [
        ApartmentEditableField.name.rawValue, ApartmentEditableField.street.rawValue,
      ])
  }

  @Test("Outbox enforces deterministic ordering, retry backoff windows, and inFlight recovery")
  func outboxOrderingAndTransitions() throws {
    let database = try makeInMemoryDatabase()
    let apartmentStore = ApartmentMutationStore(database: database)
    let outbox = OutboxRepository(database: database)

    try apartmentStore.createApartment(
      DatabaseTestFixtures.makeApartment(id: DatabaseTestFixtures.apartmentId),
      creator: DatabaseTestFixtures.makeOwnerMember(),
      outboxId: DatabaseTestFixtures.outboxTwoId,
      now: DatabaseTestFixtures.plusOneMinute
    )
    try apartmentStore.createApartment(
      DatabaseTestFixtures.makeApartment(id: DatabaseTestFixtures.secondApartmentId),
      creator: DatabaseTestFixtures.makeOwnerMember(),
      outboxId: DatabaseTestFixtures.outboxOneId,
      now: DatabaseTestFixtures.baseDate
    )

    let ordered = try outbox.fetchRunnableOperations(asOf: DatabaseTestFixtures.plusTwoMinutes)
    #expect(
      ordered.map(\.id) == [DatabaseTestFixtures.outboxOneId, DatabaseTestFixtures.outboxTwoId])

    try outbox.markInFlight(
      id: DatabaseTestFixtures.outboxOneId, now: DatabaseTestFixtures.plusTwoMinutes)
    let afterInFlight = try outbox.fetchRunnableOperations(
      asOf: DatabaseTestFixtures.plusTwoMinutes)
    #expect(afterInFlight.map(\.id) == [DatabaseTestFixtures.outboxTwoId])

    try outbox.markFailed(
      id: DatabaseTestFixtures.outboxOneId,
      errorCode: DomainErrorCode.internalError.rawValue,
      nextAttemptAt: DatabaseTestFixtures.plusFiveMinutes,
      now: DatabaseTestFixtures.plusTwoMinutes
    )
    let beforeBackoff = try outbox.fetchRunnableOperations(
      asOf: DatabaseTestFixtures.plusThreeMinutes)
    #expect(beforeBackoff.map(\.id) == [DatabaseTestFixtures.outboxTwoId])

    let atBackoff = try outbox.fetchRunnableOperations(asOf: DatabaseTestFixtures.plusFiveMinutes)
    #expect(
      atBackoff.map(\.id) == [DatabaseTestFixtures.outboxOneId, DatabaseTestFixtures.outboxTwoId])
    #expect(atBackoff.first?.attemptCount == 1)
    #expect(atBackoff.first?.lastErrorCode == DomainErrorCode.internalError.rawValue)

    try outbox.markInFlight(
      id: DatabaseTestFixtures.outboxTwoId, now: DatabaseTestFixtures.plusFiveMinutes)
    try outbox.resetInFlightToPending(now: DatabaseTestFixtures.plusFiveMinutes)
    let recovered = try outbox.fetchRunnableOperations(asOf: DatabaseTestFixtures.plusFiveMinutes)
    #expect(recovered.count == DatabaseTestFixtures.expectedCountTwo)

    try outbox.markSucceeded(id: DatabaseTestFixtures.outboxOneId)
    let remaining = try outbox.fetchAllOperations()
    #expect(remaining.map(\.id) == [DatabaseTestFixtures.outboxTwoId])
  }
}
