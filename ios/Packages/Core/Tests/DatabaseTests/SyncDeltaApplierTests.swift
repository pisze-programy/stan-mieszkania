import Database
import Domain
import Foundation
import SQLiteData
import Testing

@Suite("Hydrated Sync Delta Applier and Cursor Tests")
struct SyncDeltaApplierTests {
  @Test("Applies apartment, member, media, and entry deltas while preserving localFilePath")
  func appliesHydratedDeltasAndPreservesLocalFilePath() throws {
    let database = try makeInMemoryDatabase()
    let applier = SyncDeltaApplier(database: database)
    let mediaStore = MediaMutationStore(database: database)

    try applier.applyHydratedChange(
      SyncDeltaTestFixtures.apartmentCreated(),
      now: DatabaseTestFixtures.baseDate
    )
    #expect(
      try applier.fetchLastSeq(apartmentId: DatabaseTestFixtures.apartmentId)
        == DatabaseTestFixtures.seqOne
    )

    try mediaStore.saveLocalMedia(
      DatabaseTestFixtures.makeMedia(),
      queueForCloud: false,
      now: DatabaseTestFixtures.baseDate
    )

    try applier.applyHydratedChanges(
      [
        SyncDeltaTestFixtures.memberJoined(),
        SyncDeltaTestFixtures.mediaConfirmed(),
        SyncDeltaTestFixtures.entryCreated(),
      ],
      now: DatabaseTestFixtures.plusTwoMinutes
    )
    #expect(
      try applier.fetchLastSeq(apartmentId: DatabaseTestFixtures.apartmentId)
        == DatabaseTestFixtures.seqFour
    )

    let syncedMedia = try #require(
      database.read {
        try MediaRecord.where { $0.id.eq(DatabaseTestFixtures.mediaId) }.fetchOne($0)
      }
    )
    #expect(syncedMedia.syncState == MediaSyncState.verified.rawValue)
    #expect(syncedMedia.localFilePath == DatabaseTestFixtures.localFilePath)

    let syncedMarkers = try database.read { try MarkerRecord.fetchAll($0) }
    #expect(syncedMarkers.count == 1)
    #expect(syncedMarkers.first?.isServerAssigned == true)
  }

  @Test("Skips stale sequence deltas idempotently")
  func skipsStaleSequenceDeltas() throws {
    let database = try makeInMemoryDatabase()
    let applier = SyncDeltaApplier(database: database)
    try applier.applyHydratedChanges(
      [
        SyncDeltaTestFixtures.apartmentCreated(),
        SyncDeltaTestFixtures.mediaConfirmed(),
        SyncDeltaTestFixtures.entryCreated(),
      ],
      now: DatabaseTestFixtures.plusTwoMinutes
    )

    let staleDuplicate = HydratedSyncChange(
      seq: DatabaseTestFixtures.seqThree,
      apartmentId: DatabaseTestFixtures.apartmentId,
      entityType: DatabaseConstants.SyncEntityType.media,
      entityId: DatabaseTestFixtures.mediaId,
      op: DatabaseConstants.SyncOperation.softDeleted,
      createdAt: DatabaseTestFixtures.plusThreeMinutes,
      payload: nil
    )
    try applier.applyHydratedChange(staleDuplicate, now: DatabaseTestFixtures.plusThreeMinutes)

    let stillVerified = try #require(
      database.read {
        try MediaRecord.where { $0.id.eq(DatabaseTestFixtures.mediaId) }.fetchOne($0)
      }
    )
    #expect(stillVerified.deletedAt == nil)
    #expect(
      try applier.fetchLastSeq(apartmentId: DatabaseTestFixtures.apartmentId)
        == DatabaseTestFixtures.seqFour
    )
  }

  @Test("Applies entry retraction and media soft-delete tombstones while advancing cursor")
  func appliesEntryAndMediaTombstones() throws {
    let database = try makeInMemoryDatabase()
    let applier = SyncDeltaApplier(database: database)
    try applier.applyHydratedChanges(
      [
        SyncDeltaTestFixtures.apartmentCreated(),
        SyncDeltaTestFixtures.mediaConfirmed(),
        SyncDeltaTestFixtures.entryCreated(),
      ],
      now: DatabaseTestFixtures.plusTwoMinutes
    )

    try applier.applyHydratedChanges(
      [
        SyncDeltaTestFixtures.entryRetractedTombstone(),
        SyncDeltaTestFixtures.mediaSoftDeletedTombstone(),
      ],
      now: DatabaseTestFixtures.plusFiveMinutes
    )

    let retractedEntry = try #require(
      database.read {
        try EntryRecord.where { $0.id.eq(DatabaseTestFixtures.entryId) }.fetchOne($0)
      }
    )
    #expect(retractedEntry.retractedAt == DatabaseTestFixtures.plusThreeMinutes)
    #expect(retractedEntry.text.isEmpty)
    #expect(try database.read { try MarkerRecord.fetchAll($0) }.isEmpty)

    let tombstonedMedia = try #require(
      database.read {
        try MediaRecord.where { $0.id.eq(DatabaseTestFixtures.mediaId) }.fetchOne($0)
      }
    )
    #expect(tombstonedMedia.syncState == MediaSyncState.softDeleted.rawValue)
    #expect(tombstonedMedia.deletedAt == DatabaseTestFixtures.plusFiveMinutes)
    #expect(
      try applier.fetchLastSeq(apartmentId: DatabaseTestFixtures.apartmentId)
        == DatabaseTestFixtures.seqSix
    )
  }
}
