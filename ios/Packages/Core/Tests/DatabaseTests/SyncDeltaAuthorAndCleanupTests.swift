import Database
import Domain
import Foundation
import SQLiteData
import Testing

@Suite("SyncDelta Author Upsert, Abandoned Cleanup, and Outbox Reset Tests")
struct SyncDeltaAuthorAndCleanupTests {
  @Test("Upserts MemberRecord from media/entry author summaries and preserves joinedAt/leftAt")
  func upsertsAuthorMemberSummariesPreservingMembershipTimestamps() throws {
    let database = try makeInMemoryDatabase()
    let applier = SyncDeltaApplier(database: database)
    let ownerMemberID = MemberRecord.makeID(
      apartmentId: DatabaseTestFixtures.apartmentId,
      userId: DatabaseTestFixtures.ownerId
    )

    try applier.applyHydratedChanges(
      [SyncDeltaTestFixtures.apartmentCreated(), SyncDeltaTestFixtures.mediaConfirmed()],
      now: DatabaseTestFixtures.plusTwoMinutes
    )
    let insertedOwner = try #require(
      database.read { try MemberRecord.where { $0.id.eq(ownerMemberID) }.fetchOne($0) }
    )
    #expect(insertedOwner.displayName == "Anna Nowak")
    #expect(insertedOwner.joinedAt == DatabaseTestFixtures.baseDate)
    #expect(insertedOwner.leftAt == nil)

    try markOwnerDeparted(memberID: ownerMemberID, in: database)
    try applier.applyHydratedChange(
      makeAnonymizedEntryChange(),
      now: DatabaseTestFixtures.plusThreeMinutes
    )

    let updatedOwner = try #require(
      database.read { try MemberRecord.where { $0.id.eq(ownerMemberID) }.fetchOne($0) }
    )
    #expect(updatedOwner.displayName == "Usunięty użytkownik")
    #expect(updatedOwner.joinedAt == DatabaseTestFixtures.baseDate)
    #expect(updatedOwner.leftAt == DatabaseTestFixtures.plusOneMinute)
  }

  @Test("Handles abandoned_cleaned by reverting local-file media and deleting phantom media")
  func handlesAbandonedCleanedForLocalAndPhantomMedia() throws {
    let database = try makeInMemoryDatabase()
    let applier = SyncDeltaApplier(database: database)
    try seedLocalAndPhantomMedia(in: database, applier: applier)

    try applier.applyHydratedChanges(
      [
        makeAbandonedChange(
          seq: DatabaseTestFixtures.seqTwo, mediaId: DatabaseTestFixtures.mediaId),
        makeAbandonedChange(
          seq: DatabaseTestFixtures.seqThree,
          mediaId: DatabaseTestFixtures.secondMediaId
        ),
      ],
      now: DatabaseTestFixtures.plusThreeMinutes
    )

    let keptMedia = try #require(
      database.read {
        try MediaRecord.where { $0.id.eq(DatabaseTestFixtures.mediaId) }.fetchOne($0)
      }
    )
    #expect(keptMedia.syncState == MediaSyncState.localOnly.rawValue)
    #expect(try database.read { try EntryRecord.fetchAll($0) }.count == 1)

    let phantomMedia = try database.read {
      try MediaRecord.where { $0.id.eq(DatabaseTestFixtures.secondMediaId) }.fetchOne($0)
    }
    #expect(phantomMedia == nil)
    #expect(try OutboxRepository(database: database).fetchAllOperations().isEmpty)
  }

  @Test("resetToPending resets only the targeted operation without affecting other inFlight rows")
  func resetToPendingTargetsSingleOperationOnly() throws {
    let database = try makeInMemoryDatabase()
    let aptStore = ApartmentMutationStore(database: database)
    let outbox = OutboxRepository(database: database)

    try aptStore.createApartment(
      DatabaseTestFixtures.makeApartment(id: DatabaseTestFixtures.apartmentId),
      creator: DatabaseTestFixtures.makeOwnerMember(),
      outboxId: DatabaseTestFixtures.outboxOneId,
      now: DatabaseTestFixtures.baseDate
    )
    try aptStore.createApartment(
      DatabaseTestFixtures.makeApartment(id: DatabaseTestFixtures.secondApartmentId),
      creator: DatabaseTestFixtures.makeOwnerMember(),
      outboxId: DatabaseTestFixtures.outboxTwoId,
      now: DatabaseTestFixtures.plusOneMinute
    )

    try outbox.markInFlight(
      id: DatabaseTestFixtures.outboxOneId,
      now: DatabaseTestFixtures.plusTwoMinutes
    )
    try outbox.markInFlight(
      id: DatabaseTestFixtures.outboxTwoId,
      now: DatabaseTestFixtures.plusTwoMinutes
    )
    try outbox.resetToPending(
      id: DatabaseTestFixtures.outboxOneId,
      now: DatabaseTestFixtures.plusThreeMinutes
    )

    let all = try outbox.fetchAllOperations()
    let first = try #require(all.first { $0.id == DatabaseTestFixtures.outboxOneId })
    let second = try #require(all.first { $0.id == DatabaseTestFixtures.outboxTwoId })
    #expect(first.status == OutboxOperationStatus.pending.rawValue)
    #expect(second.status == OutboxOperationStatus.inFlight.rawValue)
  }

  private func markOwnerDeparted(memberID: String, in database: any DatabaseWriter) throws {
    try database.write { db in
      let departedOwner = MemberRecord(
        id: memberID,
        apartmentId: DatabaseTestFixtures.apartmentId,
        userId: DatabaseTestFixtures.ownerId,
        displayName: "Anna Nowak",
        shortTag: "A1B2",
        color: "#007AFF",
        role: MemberRole.owner.rawValue,
        joinedAt: DatabaseTestFixtures.baseDate,
        leftAt: DatabaseTestFixtures.plusOneMinute
      )
      try MemberRecord.upsert { departedOwner }.execute(db)
    }
  }

  private func makeAnonymizedEntryChange() -> HydratedSyncChange {
    let anonymizedAuthor = AuthorSummary(
      userId: DatabaseTestFixtures.ownerId,
      displayName: "Usunięty użytkownik",
      shortTag: "A1B2",
      color: "#007AFF",
      role: .owner
    )
    return HydratedSyncChange(
      seq: DatabaseTestFixtures.seqFour,
      apartmentId: DatabaseTestFixtures.apartmentId,
      entityType: DatabaseConstants.SyncEntityType.entry,
      entityId: DatabaseTestFixtures.entryId,
      op: "created",
      createdAt: DatabaseTestFixtures.plusThreeMinutes,
      payload: .entry(
        HydratedSyncEntry(
          id: DatabaseTestFixtures.entryId,
          mediaId: DatabaseTestFixtures.mediaId,
          authorId: DatabaseTestFixtures.ownerId,
          text: "Wpis",
          markers: [],
          createdAt: DatabaseTestFixtures.plusThreeMinutes,
          serverReceivedAt: DatabaseTestFixtures.plusThreeMinutes,
          retractedAt: nil,
          author: anonymizedAuthor
        )
      )
    )
  }

  private func seedLocalAndPhantomMedia(
    in database: any DatabaseWriter,
    applier: SyncDeltaApplier
  ) throws {
    let mediaStore = MediaMutationStore(database: database)
    try applier.applyHydratedChange(
      SyncDeltaTestFixtures.apartmentCreated(),
      now: DatabaseTestFixtures.baseDate
    )
    try mediaStore.saveLocalMedia(
      DatabaseTestFixtures.makeMedia(id: DatabaseTestFixtures.mediaId),
      initialEntry: DatabaseTestFixtures.makeEntry(),
      queueForCloud: true,
      mediaOutboxId: DatabaseTestFixtures.outboxOneId,
      entryOutboxId: DatabaseTestFixtures.outboxTwoId,
      now: DatabaseTestFixtures.baseDate
    )
    try mediaStore.saveLocalMedia(
      DatabaseTestFixtures.makeMedia(id: DatabaseTestFixtures.secondMediaId, localFilePath: nil),
      queueForCloud: true,
      mediaOutboxId: DatabaseTestFixtures.outboxThreeId,
      now: DatabaseTestFixtures.baseDate
    )
  }

  private func makeAbandonedChange(seq: Int, mediaId: String) -> HydratedSyncChange {
    HydratedSyncChange(
      seq: seq,
      apartmentId: DatabaseTestFixtures.apartmentId,
      entityType: DatabaseConstants.SyncEntityType.media,
      entityId: mediaId,
      op: DatabaseConstants.SyncOperation.abandonedCleaned,
      createdAt: DatabaseTestFixtures.plusTwoMinutes,
      payload: nil
    )
  }
}
