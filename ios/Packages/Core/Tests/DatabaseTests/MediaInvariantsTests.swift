import Database
import Domain
import Foundation
import SQLiteData
import Testing

@Suite("Media Local-vs-Cloud Invariants and QUOTA_EXCEEDED Tests")
struct MediaInvariantsTests {
  @Test("Local-only media allows author hard-delete removing DB rows and unstarted outbox ops")
  func localMediaHardDeleteRemovesRowsAndUnstartedOutbox() throws {
    let database = try makeInMemoryDatabase()
    try seedApartment(in: database)
    let mediaStore = MediaMutationStore(database: database)
    let outbox = OutboxRepository(database: database)

    let marker = DatabaseTestFixtures.makeMarker(
      id: DatabaseTestFixtures.markerOneId,
      number: DatabaseTestFixtures.markerOneNumber
    )
    let entry = DatabaseTestFixtures.makeEntry(markers: [marker])
    try mediaStore.saveLocalMedia(
      DatabaseTestFixtures.makeMedia(),
      initialEntry: entry,
      queueForCloud: true,
      mediaOutboxId: DatabaseTestFixtures.outboxTwoId,
      entryOutboxId: DatabaseTestFixtures.outboxThreeId,
      now: DatabaseTestFixtures.plusOneMinute
    )

    #expect(
      throws: AppDatabaseError.mediaAuthorMismatch(
        mediaId: DatabaseTestFixtures.mediaId,
        actorId: DatabaseTestFixtures.contributorId
      )
    ) {
      try mediaStore.hardDeleteLocalMedia(
        mediaId: DatabaseTestFixtures.mediaId,
        actorId: DatabaseTestFixtures.contributorId
      )
    }

    #expect(throws: AppDatabaseError.cannotSoftDeleteUnsyncedMedia(DatabaseTestFixtures.mediaId)) {
      try mediaStore.softDeleteSyncedMedia(
        mediaId: DatabaseTestFixtures.mediaId,
        actorId: DatabaseTestFixtures.ownerId,
        now: DatabaseTestFixtures.plusTwoMinutes
      )
    }

    let removedPath = try mediaStore.hardDeleteLocalMedia(
      mediaId: DatabaseTestFixtures.mediaId,
      actorId: DatabaseTestFixtures.ownerId
    )
    #expect(removedPath == DatabaseTestFixtures.localFilePath)
    #expect(try database.read { try MediaRecord.fetchAll($0) }.isEmpty)
    #expect(try database.read { try EntryRecord.fetchAll($0) }.isEmpty)
    #expect(try database.read { try MarkerRecord.fetchAll($0) }.isEmpty)
    #expect(try outbox.fetchAllOperations().map(\.id) == [DatabaseTestFixtures.outboxOneId])
  }

  @Test("Confirming media clears GPS metadata and updates cloudMediaCount")
  func confirmMediaClearsGpsAndUpdatesQuotaCount() throws {
    let database = try makeInMemoryDatabase()
    try seedSyncedMedia(in: database)

    let verified = try fetchMedia(in: database)
    #expect(verified.syncState == MediaSyncState.verified.rawValue)
    #expect(verified.captureLocation == nil)

    let apartment = try #require(
      database.read {
        try ApartmentRecord.where { $0.id.eq(DatabaseTestFixtures.apartmentId) }.fetchOne($0)
      }
    )
    #expect(apartment.cloudMediaCount == DatabaseTestFixtures.cloudCountThree)
  }

  @Test("Synced media rejects hard-delete and allows only author soft-delete with outbox op")
  func syncedMediaRejectsHardDeleteAndAllowsAuthorSoftDelete() throws {
    let database = try makeInMemoryDatabase()
    try seedSyncedMedia(in: database)
    let mediaStore = MediaMutationStore(database: database)
    let outbox = OutboxRepository(database: database)

    #expect(throws: AppDatabaseError.cannotHardDeleteSyncedMedia(DatabaseTestFixtures.mediaId)) {
      try mediaStore.hardDeleteLocalMedia(
        mediaId: DatabaseTestFixtures.mediaId,
        actorId: DatabaseTestFixtures.ownerId
      )
    }

    #expect(
      throws: AppDatabaseError.mediaAuthorMismatch(
        mediaId: DatabaseTestFixtures.mediaId,
        actorId: DatabaseTestFixtures.contributorId
      )
    ) {
      try mediaStore.softDeleteSyncedMedia(
        mediaId: DatabaseTestFixtures.mediaId,
        actorId: DatabaseTestFixtures.contributorId,
        outboxId: DatabaseTestFixtures.outboxThreeId,
        now: DatabaseTestFixtures.plusThreeMinutes
      )
    }

    try mediaStore.softDeleteSyncedMedia(
      mediaId: DatabaseTestFixtures.mediaId,
      actorId: DatabaseTestFixtures.ownerId,
      outboxId: DatabaseTestFixtures.outboxThreeId,
      now: DatabaseTestFixtures.plusThreeMinutes
    )

    let softDeleted = try fetchMedia(in: database)
    #expect(softDeleted.syncState == MediaSyncState.softDeleted.rawValue)
    #expect(softDeleted.deletedAt == DatabaseTestFixtures.plusThreeMinutes)
    #expect(softDeleted.deletedBy == DatabaseTestFixtures.ownerId)

    let softDeleteOps = try outbox.fetchAllOperations().filter {
      $0.operationType == OutboxOperationType.softDeleteMedia.rawValue
    }
    #expect(softDeleteOps.count == 1)
    #expect(softDeleteOps.first?.entityId == DatabaseTestFixtures.mediaId)
  }

  @Test(
    "QUOTA_EXCEEDED reverts queued or uploading media to localOnly without losing photo or entries")
  func quotaExceededRevertsToLocalOnlyPreservingMediaAndEntries() throws {
    let database = try makeInMemoryDatabase()
    try seedApartment(in: database)
    let mediaStore = MediaMutationStore(database: database)
    let outbox = OutboxRepository(database: database)

    let marker = DatabaseTestFixtures.makeMarker(
      id: DatabaseTestFixtures.markerOneId,
      number: DatabaseTestFixtures.markerOneNumber
    )
    let entry = DatabaseTestFixtures.makeEntry(markers: [marker])
    try mediaStore.saveLocalMedia(
      DatabaseTestFixtures.makeMedia(),
      initialEntry: entry,
      queueForCloud: true,
      mediaOutboxId: DatabaseTestFixtures.outboxTwoId,
      entryOutboxId: DatabaseTestFixtures.outboxThreeId,
      now: DatabaseTestFixtures.plusOneMinute
    )
    try mediaStore.markMediaUploading(mediaId: DatabaseTestFixtures.mediaId)
    try mediaStore.handleQuotaExceeded(mediaId: DatabaseTestFixtures.mediaId)

    let media = try fetchMedia(in: database)
    #expect(media.syncState == MediaSyncState.localOnly.rawValue)
    #expect(media.serverReceivedAt == nil)
    #expect(media.localFilePath == DatabaseTestFixtures.localFilePath)
    #expect(try database.read { try EntryRecord.fetchAll($0) }.count == 1)
    #expect(try database.read { try MarkerRecord.fetchAll($0) }.count == 1)
    #expect(try outbox.fetchAllOperations().map(\.id) == [DatabaseTestFixtures.outboxOneId])
  }

  private func fetchMedia(in database: any DatabaseWriter) throws -> MediaRecord {
    try #require(
      database.read {
        try MediaRecord.where { $0.id.eq(DatabaseTestFixtures.mediaId) }.fetchOne($0)
      }
    )
  }

  private func seedApartment(in database: any DatabaseWriter) throws {
    let apartmentStore = ApartmentMutationStore(database: database)
    try apartmentStore.createApartment(
      DatabaseTestFixtures.makeApartment(),
      creator: DatabaseTestFixtures.makeOwnerMember(),
      outboxId: DatabaseTestFixtures.outboxOneId,
      now: DatabaseTestFixtures.baseDate
    )
  }

  private func seedSyncedMedia(in database: any DatabaseWriter) throws {
    try seedApartment(in: database)
    let mediaStore = MediaMutationStore(database: database)
    let location = CaptureLocationMetadata(
      lat: DatabaseTestFixtures.lat,
      lng: DatabaseTestFixtures.lng,
      accuracyM: DatabaseTestFixtures.accuracyM,
      locationSource: .device
    )
    try mediaStore.saveLocalMedia(
      DatabaseTestFixtures.makeMedia(),
      location: location,
      queueForCloud: true,
      mediaOutboxId: DatabaseTestFixtures.outboxTwoId,
      now: DatabaseTestFixtures.plusOneMinute
    )
    try mediaStore.markMediaUploading(mediaId: DatabaseTestFixtures.mediaId)
    try mediaStore.confirmMediaUploaded(
      mediaId: DatabaseTestFixtures.mediaId,
      serverReceivedAt: DatabaseTestFixtures.plusTwoMinutes,
      cloudMediaCount: DatabaseTestFixtures.cloudCountThree
    )
  }
}
