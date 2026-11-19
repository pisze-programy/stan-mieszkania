import Database
import Domain
import Foundation
import SQLiteData
import Testing

@Suite("Database Schema, Migrations, and Fetch Compatibility")
struct DatabaseSchemaAndFetchTests {
  @Test("Migrator creates all tables and supports @FetchAll and @FetchOne via defaultDatabase")
  func migrationsAndFetchWrappersWork() async throws {
    let database = try makeInMemoryDatabase()
    let tableNames = try await database.read { db in
      try String.fetchAll(
        db,
        sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
      )
    }

    let expectedTables: Set<String> = [
      DatabaseConstants.TableName.localUsers,
      DatabaseConstants.TableName.apartments,
      DatabaseConstants.TableName.apartmentChanges,
      DatabaseConstants.TableName.members,
      DatabaseConstants.TableName.media,
      DatabaseConstants.TableName.entries,
      DatabaseConstants.TableName.markers,
      DatabaseConstants.TableName.outboxOperations,
      DatabaseConstants.TableName.syncCursors,
    ]
    #expect(expectedTables.isSubset(of: Set(tableNames)))

    let apartmentStore = ApartmentMutationStore(database: database)
    try apartmentStore.saveLocalUser(DatabaseTestFixtures.makeOwnerProfile())
    try apartmentStore.createApartment(
      DatabaseTestFixtures.makeApartment(),
      creator: DatabaseTestFixtures.makeOwnerMember(),
      outboxId: DatabaseTestFixtures.outboxOneId,
      now: DatabaseTestFixtures.baseDate
    )

    try await withDependencies {
      $0.defaultDatabase = database
    } operation: {
      @FetchAll(ApartmentRecord.order { $0.createdAt.asc() })
      var fetchedApartments: [ApartmentRecord]
      @FetchOne(ApartmentRecord.count())
      var apartmentCount = 0

      try await $fetchedApartments.load()
      try await $apartmentCount.load()

      #expect(fetchedApartments.count == 1)
      #expect(fetchedApartments.first?.id == DatabaseTestFixtures.apartmentId)
      #expect(apartmentCount == 1)
    }
  }

  @Test("Disk-backed makeAppDatabase persists data and enforces foreign keys across reopen")
  func diskDatabasePersistsAndEnforcesForeignKeys() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let dbPath = directory.appendingPathComponent(DatabaseConstants.defaultFilename).path
    defer { try? FileManager.default.removeItem(at: directory) }

    do {
      let writer = try makeAppDatabase(atPath: dbPath)
      let store = ApartmentMutationStore(database: writer)
      try store.createApartment(
        DatabaseTestFixtures.makeApartment(),
        creator: DatabaseTestFixtures.makeOwnerMember(),
        outboxId: DatabaseTestFixtures.outboxOneId,
        now: DatabaseTestFixtures.baseDate
      )

      let orphanMedia = MediaRecord(item: DatabaseTestFixtures.makeMedia(apartmentId: "missing"))
      #expect(throws: (any Error).self) {
        try writer.write { db in
          try MediaRecord.insert { orphanMedia }.execute(db)
        }
      }
    }

    let reopened = try makeAppDatabase(atPath: dbPath)
    let persisted = try reopened.read { db in
      try ApartmentRecord.where { $0.id.eq(DatabaseTestFixtures.apartmentId) }.fetchOne(db)
    }
    let persistedRecord = try #require(persisted)
    let domainApartment = try persistedRecord.toDomain()
    #expect(domainApartment.name == "Mieszkanie Mokotow")
    #expect(domainApartment.role == .owner)
  }

  @Test("Allows duplicate temporary marker numbers but rejects duplicate server-assigned numbers")
  func partialUniqueIndexOnServerAssignedMarkers() throws {
    let database = try makeInMemoryDatabase()
    try seedMedia(in: database)
    let entryStore = EntryMutationStore(database: database)
    let firstDraft = DatabaseTestFixtures.makeMarker(
      id: DatabaseTestFixtures.markerOneId,
      entryId: DatabaseTestFixtures.entryId,
      number: DatabaseTestFixtures.markerOneNumber
    )
    let secondDraft = DatabaseTestFixtures.makeMarker(
      id: DatabaseTestFixtures.markerTwoId,
      entryId: DatabaseTestFixtures.secondEntryId,
      number: DatabaseTestFixtures.markerOneNumber
    )
    try entryStore.createEntry(
      DatabaseTestFixtures.makeEntry(id: DatabaseTestFixtures.entryId, markers: [firstDraft]),
      queueForCloud: false,
      now: DatabaseTestFixtures.baseDate
    )
    try entryStore.createEntry(
      DatabaseTestFixtures.makeEntry(
        id: DatabaseTestFixtures.secondEntryId,
        markers: [secondDraft]
      ),
      queueForCloud: false,
      now: DatabaseTestFixtures.plusOneMinute
    )

    let confirmedOne = DatabaseTestFixtures.makeMarker(
      id: DatabaseTestFixtures.markerOneId,
      entryId: DatabaseTestFixtures.entryId,
      number: DatabaseTestFixtures.markerOneNumber,
      isServerAssigned: true
    )
    try entryStore.confirmEntrySynced(
      entryId: DatabaseTestFixtures.entryId,
      serverReceivedAt: DatabaseTestFixtures.plusTwoMinutes,
      serverMarkers: [confirmedOne]
    )

    let conflictingTwo = DatabaseTestFixtures.makeMarker(
      id: DatabaseTestFixtures.markerTwoId,
      entryId: DatabaseTestFixtures.secondEntryId,
      number: DatabaseTestFixtures.markerOneNumber,
      isServerAssigned: true
    )
    #expect(throws: (any Error).self) {
      try entryStore.confirmEntrySynced(
        entryId: DatabaseTestFixtures.secondEntryId,
        serverReceivedAt: DatabaseTestFixtures.plusThreeMinutes,
        serverMarkers: [conflictingTwo]
      )
    }
  }

  private func seedMedia(in database: any DatabaseWriter) throws {
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
  }
}
