import Database
import Domain
import Foundation
import SQLiteData
import Testing

@Suite("Synced Entry Immutability and Retraction S2-3 Tests")
struct EntryRetractionTests {
  @Test("Synced entry rejects edits and hard-delete")
  func syncedEntryRejectsEditsAndHardDelete() throws {
    let database = try makeInMemoryDatabase()
    try seedSyncedEntry(in: database)
    let entryStore = EntryMutationStore(database: database)

    #expect(throws: AppDatabaseError.cannotEditSyncedEntry(DatabaseTestFixtures.entryId)) {
      try entryStore.updateLocalEntry(
        entryId: DatabaseTestFixtures.entryId,
        actorId: DatabaseTestFixtures.ownerId,
        text: "Nowy tekst",
        markers: [],
        now: DatabaseTestFixtures.plusThreeMinutes
      )
    }

    #expect(throws: AppDatabaseError.cannotHardDeleteSyncedEntry(DatabaseTestFixtures.entryId)) {
      try entryStore.hardDeleteLocalEntry(
        entryId: DatabaseTestFixtures.entryId,
        actorId: DatabaseTestFixtures.ownerId
      )
    }
  }

  @Test("Synced entry allows only author retraction clearing text and markers with outbox op")
  func syncedEntryAllowsOnlyAuthorRetraction() throws {
    let database = try makeInMemoryDatabase()
    try seedSyncedEntry(in: database)
    let entryStore = EntryMutationStore(database: database)
    let outbox = OutboxRepository(database: database)

    #expect(
      throws: AppDatabaseError.entryAuthorMismatch(
        entryId: DatabaseTestFixtures.entryId,
        actorId: DatabaseTestFixtures.contributorId
      )
    ) {
      try entryStore.retractSyncedEntry(
        entryId: DatabaseTestFixtures.entryId,
        actorId: DatabaseTestFixtures.contributorId,
        outboxId: DatabaseTestFixtures.outboxThreeId,
        now: DatabaseTestFixtures.plusThreeMinutes
      )
    }

    try entryStore.retractSyncedEntry(
      entryId: DatabaseTestFixtures.entryId,
      actorId: DatabaseTestFixtures.ownerId,
      outboxId: DatabaseTestFixtures.outboxThreeId,
      now: DatabaseTestFixtures.plusThreeMinutes
    )

    let retracted = try #require(
      database.read {
        try EntryRecord.where { $0.id.eq(DatabaseTestFixtures.entryId) }.fetchOne($0)
      }
    )
    #expect(retracted.retractedAt == DatabaseTestFixtures.plusThreeMinutes)
    #expect(retracted.text.isEmpty)
    #expect(try database.read { try MarkerRecord.fetchAll($0) }.isEmpty)

    let retractOps = try outbox.fetchAllOperations().filter {
      $0.operationType == OutboxOperationType.retractEntry.rawValue
    }
    #expect(retractOps.count == 1)
    #expect(retractOps.first?.entityId == DatabaseTestFixtures.entryId)
  }

  private func seedSyncedEntry(in database: any DatabaseWriter) throws {
    let apartmentStore = ApartmentMutationStore(database: database)
    try apartmentStore.createApartment(
      DatabaseTestFixtures.makeApartment(),
      creator: DatabaseTestFixtures.makeOwnerMember(),
      outboxId: DatabaseTestFixtures.outboxOneId,
      now: DatabaseTestFixtures.baseDate
    )
    let mediaStore = MediaMutationStore(database: database)
    try mediaStore.saveLocalMedia(
      DatabaseTestFixtures.makeMedia(),
      queueForCloud: false,
      now: DatabaseTestFixtures.baseDate
    )
    let entryStore = EntryMutationStore(database: database)
    let marker = DatabaseTestFixtures.makeMarker(
      id: DatabaseTestFixtures.markerOneId,
      number: DatabaseTestFixtures.markerOneNumber
    )
    try entryStore.createEntry(
      DatabaseTestFixtures.makeEntry(text: "Wpis [1]", markers: [marker]),
      queueForCloud: true,
      outboxId: DatabaseTestFixtures.outboxTwoId,
      now: DatabaseTestFixtures.plusOneMinute
    )
    let confirmedMarker = DatabaseTestFixtures.makeMarker(
      id: DatabaseTestFixtures.markerOneId,
      number: DatabaseTestFixtures.markerOneNumber,
      isServerAssigned: true
    )
    try entryStore.confirmEntrySynced(
      entryId: DatabaseTestFixtures.entryId,
      serverReceivedAt: DatabaseTestFixtures.plusTwoMinutes,
      serverMarkers: [confirmedMarker]
    )
  }
}
