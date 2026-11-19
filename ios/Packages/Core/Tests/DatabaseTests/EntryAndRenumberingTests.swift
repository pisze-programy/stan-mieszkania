import Database
import Domain
import Foundation
import SQLiteData
import Testing

@Suite("Entry Local Editing and Atomic Marker Renumbering Tests")
struct EntryAndRenumberingTests {
  @Test("Local-only entry allows editing text/markers and updates pending outbox payload")
  func localEntryEditingUpdatesDbAndOutbox() throws {
    let database = try makeInMemoryDatabase()
    try seedApartmentAndLocalMedia(in: database)
    let entryStore = EntryMutationStore(database: database)
    let outbox = OutboxRepository(database: database)

    let markerOne = DatabaseTestFixtures.makeMarker(
      id: DatabaseTestFixtures.markerOneId,
      number: DatabaseTestFixtures.markerOneNumber
    )
    try entryStore.createEntry(
      DatabaseTestFixtures.makeEntry(text: "Stary opis [1]", markers: [markerOne]),
      queueForCloud: true,
      outboxId: DatabaseTestFixtures.outboxTwoId,
      now: DatabaseTestFixtures.plusOneMinute
    )

    let markerTwo = DatabaseTestFixtures.makeMarker(
      id: DatabaseTestFixtures.markerTwoId,
      number: DatabaseTestFixtures.markerTwoNumber,
      x: DatabaseTestFixtures.coordMid,
      y: DatabaseTestFixtures.coordHigh
    )
    try entryStore.updateLocalEntry(
      entryId: DatabaseTestFixtures.entryId,
      actorId: DatabaseTestFixtures.ownerId,
      text: "Poprawiony opis [1] i [2]",
      markers: [markerOne, markerTwo],
      now: DatabaseTestFixtures.plusTwoMinutes
    )

    let updatedEntry = try #require(
      database.read {
        try EntryRecord.where { $0.id.eq(DatabaseTestFixtures.entryId) }.fetchOne($0)
      }
    )
    #expect(updatedEntry.text == "Poprawiony opis [1] i [2]")

    let markers = try database.read {
      try MarkerRecord.where { $0.entryId.eq(DatabaseTestFixtures.entryId) }
        .order { $0.number.asc() }
        .fetchAll($0)
    }
    #expect(
      markers.map(\.number) == [
        DatabaseTestFixtures.markerOneNumber,
        DatabaseTestFixtures.markerTwoNumber,
      ]
    )

    let queuedOp = try #require(
      outbox.fetchAllOperations().first { $0.id == DatabaseTestFixtures.outboxTwoId }
    )
    let decodedPayload = try queuedOp.decodePayload(CreateEntryOutboxPayload.self)
    #expect(decodedPayload.text == "Poprawiony opis [1] i [2]")
    #expect(decodedPayload.markers.count == DatabaseTestFixtures.expectedCountTwo)
  }

  @Test("Local-only entry rejects retraction and allows author hard-delete")
  func localEntryHardDeleteRemovesMarkersAndOutbox() throws {
    let database = try makeInMemoryDatabase()
    try seedApartmentAndLocalMedia(in: database)
    let entryStore = EntryMutationStore(database: database)
    let outbox = OutboxRepository(database: database)

    let markerOne = DatabaseTestFixtures.makeMarker(
      id: DatabaseTestFixtures.markerOneId,
      number: DatabaseTestFixtures.markerOneNumber
    )
    try entryStore.createEntry(
      DatabaseTestFixtures.makeEntry(text: "Opis [1]", markers: [markerOne]),
      queueForCloud: true,
      outboxId: DatabaseTestFixtures.outboxTwoId,
      now: DatabaseTestFixtures.plusOneMinute
    )

    #expect(throws: AppDatabaseError.cannotRetractUnsyncedEntry(DatabaseTestFixtures.entryId)) {
      try entryStore.retractSyncedEntry(
        entryId: DatabaseTestFixtures.entryId,
        actorId: DatabaseTestFixtures.ownerId,
        now: DatabaseTestFixtures.plusTwoMinutes
      )
    }

    try entryStore.hardDeleteLocalEntry(
      entryId: DatabaseTestFixtures.entryId,
      actorId: DatabaseTestFixtures.ownerId
    )
    #expect(try database.read { try EntryRecord.fetchAll($0) }.isEmpty)
    #expect(try database.read { try MarkerRecord.fetchAll($0) }.isEmpty)
    #expect(try outbox.fetchAllOperations().map(\.id) == [DatabaseTestFixtures.outboxOneId])
  }

  @Test("Server confirmation atomically renumbers markers and rewrites text tokens without cascade")
  func confirmEntrySyncedRenumbersMarkersAtomically() throws {
    let database = try makeInMemoryDatabase()
    try seedApartmentAndLocalMedia(in: database)
    let entryStore = EntryMutationStore(database: database)
    let outbox = OutboxRepository(database: database)

    let drafts = [
      DatabaseTestFixtures.makeMarker(
        id: DatabaseTestFixtures.markerOneId, number: DatabaseTestFixtures.markerOneNumber),
      DatabaseTestFixtures.makeMarker(
        id: DatabaseTestFixtures.markerTwoId, number: DatabaseTestFixtures.markerTwoNumber),
    ]
    try entryStore.createEntry(
      DatabaseTestFixtures.makeEntry(text: "Rysa [1] oraz plama [2] obok [1]", markers: drafts),
      queueForCloud: true,
      outboxId: DatabaseTestFixtures.outboxTwoId,
      now: DatabaseTestFixtures.plusOneMinute
    )

    let serverMarkers = [
      DatabaseTestFixtures.makeMarker(
        id: DatabaseTestFixtures.markerOneId,
        number: DatabaseTestFixtures.markerTwoNumber,
        isServerAssigned: true
      ),
      DatabaseTestFixtures.makeMarker(
        id: DatabaseTestFixtures.markerTwoId,
        number: DatabaseTestFixtures.markerThreeNumber,
        isServerAssigned: true
      ),
    ]
    let confirmed = try entryStore.confirmEntrySynced(
      entryId: DatabaseTestFixtures.entryId,
      serverReceivedAt: DatabaseTestFixtures.plusTwoMinutes,
      serverMarkers: serverMarkers
    )

    #expect(confirmed.text == "Rysa [2] oraz plama [3] obok [2]")
    #expect(confirmed.serverReceivedAt == DatabaseTestFixtures.plusTwoMinutes)

    let persistedMarkers = try database.read {
      try MarkerRecord.where { $0.entryId.eq(DatabaseTestFixtures.entryId) }
        .order { $0.number.asc() }
        .fetchAll($0)
    }
    let expectedNumbers = [
      DatabaseTestFixtures.markerTwoNumber, DatabaseTestFixtures.markerThreeNumber,
    ]
    #expect(persistedMarkers.map(\.number) == expectedNumbers)
    let allServerAssigned = persistedMarkers.allSatisfy(\.isServerAssigned)
    #expect(allServerAssigned)
    #expect(try outbox.fetchAllOperations().map(\.id) == [DatabaseTestFixtures.outboxOneId])
  }

  private func seedApartmentAndLocalMedia(in database: any DatabaseWriter) throws {
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
