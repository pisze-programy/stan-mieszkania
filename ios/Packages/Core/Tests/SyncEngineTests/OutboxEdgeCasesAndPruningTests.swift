import APIClient
import Database
import Domain
import Foundation
import MediaStorage
import SQLiteData
import SyncEngine
import Testing

@Suite("SyncEngine Revoked Pruning, Unachievable Entries, and Server Text Tests")
struct OutboxEdgeCasesAndPruningTests {
  private static let localOnlyAptId = "01933e2a-7b40-7000-8000-000000000099"
  private static let revokedAptId = "01933e2a-7b40-7000-8000-000000000098"
  private static let entryOnDeletedId = "01933e2a-7b40-7000-8000-000000000039"

  @Test("syncAllOnEntry prunes revoked apartments and keeps unsynced local apartment creations")
  func syncAllOnEntryPrunesRevokedApartmentsOnly() async throws {
    let database = try makeInMemoryDatabase()
    try await seedActiveRevokedAndLocalApartments(in: database)

    let activeSummary = APIMyApartmentSyncSummary(
      apartment: SyncEngineTestFixtures.makeApartment(),
      role: .owner,
      headSeq: 0,
      confirmedMediaCount: 0,
      latestMediaCapturedAt: nil
    )
    var apiClient = APIClient()
    apiClient.listMyApartmentsSync = { [activeSummary] }

    let actor = SyncEngineActor(
      database: database,
      apiClient: apiClient,
      mediaStorage: MediaStorageClient(),
      objectTransfer: ObjectTransferClient(),
      clock: { SyncEngineTestFixtures.confirmedDate }
    )
    _ = try await actor.syncAllOnEntry()

    let remainingIds = Set(try await database.read { try ApartmentRecord.fetchAll($0).map(\.id) })
    #expect(remainingIds == [SyncEngineTestFixtures.apartmentId, Self.localOnlyAptId])
    let remainingOps = try OutboxRepository(database: database).fetchAllOperations()
    #expect(remainingOps.map(\.id) == [SyncEngineTestFixtures.outboxEntryId])
  }

  @Test("Drops unachievable createEntry outbox ops for softDeleted and unqueued localOnly media")
  func dropsUnachievableCreateEntryOutboxOps() async throws {
    let database = try makeInMemoryDatabase()
    try await seedUnachievableEntries(in: database)

    let actor = SyncEngineActor(
      database: database,
      apiClient: APIClient(),
      mediaStorage: MediaStorageClient(),
      objectTransfer: ObjectTransferClient(),
      clock: { SyncEngineTestFixtures.confirmedDate }
    )
    let report = await actor.processOutbox()
    #expect(report.failedCount == 0)
    #expect(report.deferredCount == 0)
    #expect(try OutboxRepository(database: database).fetchAllOperations().isEmpty)

    let preservedLocalDraft = try await database.read {
      try EntryRecord.where { $0.id.eq(SyncEngineTestFixtures.entryId) }.fetchOne($0)
    }
    #expect(preservedLocalDraft != nil)
  }

  private func seedActiveRevokedAndLocalApartments(in database: any DatabaseWriter) async throws {
    let aptStore = ApartmentMutationStore(database: database)
    try aptStore.createApartment(
      SyncEngineTestFixtures.makeApartment(inviteCode: nil),
      creator: SyncEngineTestFixtures.makeOwnerMember(),
      outboxId: SyncEngineTestFixtures.outboxAptId,
      now: SyncEngineTestFixtures.baseDate
    )
    try OutboxRepository(database: database).markSucceeded(id: SyncEngineTestFixtures.outboxAptId)

    let revoked = Apartment(
      id: Self.revokedAptId, ownerId: SyncEngineTestFixtures.ownerId, name: "Revoked",
      street: "Stara 1", city: "Krakow", role: .contributor,
      createdAt: SyncEngineTestFixtures.baseDate, updatedAt: SyncEngineTestFixtures.baseDate
    )
    try await database.write { db in
      let rec = ApartmentRecord(apartment: revoked)
      try ApartmentRecord.insert { rec }.execute(db)
    }
    try aptStore.updateApartmentMetadata(
      ApartmentMetadataUpdate(
        apartmentId: Self.revokedAptId, name: "Stale", street: "Stara 1",
        city: "Krakow", authorId: SyncEngineTestFixtures.ownerId
      ),
      outboxId: SyncEngineTestFixtures.outboxMediaId,
      now: SyncEngineTestFixtures.baseDate
    )
    let localNew = Apartment(
      id: Self.localOnlyAptId, ownerId: SyncEngineTestFixtures.ownerId, name: "Nowe",
      street: "Nowa 2", city: "Gdansk", role: .owner,
      createdAt: SyncEngineTestFixtures.baseDate, updatedAt: SyncEngineTestFixtures.baseDate
    )
    try aptStore.createApartment(
      localNew,
      creator: SyncEngineTestFixtures.makeOwnerMember(),
      outboxId: SyncEngineTestFixtures.outboxEntryId,
      now: SyncEngineTestFixtures.baseDate
    )
  }

  private func seedUnachievableEntries(in database: any DatabaseWriter) async throws {
    try await database.write { db in
      let apt = ApartmentRecord(apartment: SyncEngineTestFixtures.makeApartment())
      try ApartmentRecord.insert { apt }.execute(db)
    }
    let mediaStore = MediaMutationStore(database: database)
    try mediaStore.saveLocalMedia(
      SyncEngineTestFixtures.makeMediaItem(id: SyncEngineTestFixtures.mediaOneId),
      queueForCloud: false, now: SyncEngineTestFixtures.baseDate
    )
    try mediaStore.saveLocalMedia(
      SyncEngineTestFixtures.makeMediaItem(id: SyncEngineTestFixtures.mediaTwoId),
      queueForCloud: false, now: SyncEngineTestFixtures.baseDate
    )
    try mediaStore.confirmMediaUploaded(
      mediaId: SyncEngineTestFixtures.mediaTwoId, serverReceivedAt: SyncEngineTestFixtures.baseDate
    )
    try mediaStore.softDeleteSyncedMedia(
      mediaId: SyncEngineTestFixtures.mediaTwoId, actorId: SyncEngineTestFixtures.ownerId,
      outboxId: SyncEngineTestFixtures.outboxAptId, now: SyncEngineTestFixtures.baseDate
    )
    try OutboxRepository(database: database).markSucceeded(id: SyncEngineTestFixtures.outboxAptId)

    let entryStore = EntryMutationStore(database: database)
    try entryStore.createEntry(
      SyncEngineTestFixtures.makeDraftEntry(),
      queueForCloud: true, outboxId: SyncEngineTestFixtures.outboxMediaId,
      now: SyncEngineTestFixtures.baseDate
    )
    let entryOnDeleted = EntryItem(
      id: Self.entryOnDeletedId, mediaId: SyncEngineTestFixtures.mediaTwoId,
      authorId: SyncEngineTestFixtures.ownerId, text: "Wpis",
      createdAt: SyncEngineTestFixtures.baseDate
    )
    try entryStore.createEntry(
      entryOnDeleted, queueForCloud: true,
      outboxId: SyncEngineTestFixtures.outboxEntryId, now: SyncEngineTestFixtures.baseDate
    )
  }
}
