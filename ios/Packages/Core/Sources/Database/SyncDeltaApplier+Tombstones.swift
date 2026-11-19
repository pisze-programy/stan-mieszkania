import Domain
import Foundation
import SQLiteData

extension SyncDeltaApplier {
  func upsertAuthorMember(
    _ author: AuthorSummary,
    apartmentId: String,
    fallbackJoinedAt: Date,
    in db: Database
  ) throws {
    let memberID = MemberRecord.makeID(apartmentId: apartmentId, userId: author.userId)
    let existing = try MemberRecord.where { $0.id.eq(memberID) }.fetchOne(db)
    let record = MemberRecord(
      id: memberID,
      apartmentId: apartmentId,
      userId: author.userId,
      displayName: author.displayName,
      shortTag: author.shortTag,
      color: author.color,
      role: author.role.rawValue,
      joinedAt: existing?.joinedAt ?? fallbackJoinedAt,
      leftAt: existing?.leftAt
    )
    try MemberRecord.upsert { record }.execute(db)
  }

  func applyTombstone(_ change: HydratedSyncChange, in db: Database) throws {
    switch (change.entityType, change.op) {
    case (DatabaseConstants.SyncEntityType.apartment, DatabaseConstants.SyncOperation.deleted):
      try ApartmentRecord
        .where { $0.id.eq(change.entityId) }
        .update { $0.deletedAt = #bind(change.createdAt) }
        .execute(db)
      try OutboxRepository.deleteOperationsForApartment(in: db, apartmentId: change.apartmentId)

    case (DatabaseConstants.SyncEntityType.media, DatabaseConstants.SyncOperation.softDeleted):
      let softDeleted = MediaSyncState.softDeleted.rawValue
      try MediaRecord
        .where { $0.id.eq(change.entityId) }
        .update {
          $0.deletedAt = #bind(change.createdAt)
          $0.syncState = softDeleted
        }
        .execute(db)

    case (DatabaseConstants.SyncEntityType.media, DatabaseConstants.SyncOperation.abandonedCleaned):
      try handleAbandonedMediaCleanup(mediaId: change.entityId, in: db)

    case (DatabaseConstants.SyncEntityType.entry, DatabaseConstants.SyncOperation.retracted):
      let clearedText = DatabaseConstants.retractedEntryText
      try EntryRecord
        .where { $0.id.eq(change.entityId) }
        .update {
          $0.text = clearedText
          $0.retractedAt = #bind(change.createdAt)
        }
        .execute(db)
      try MarkerRecord
        .where { $0.entryId.eq(change.entityId) }
        .delete()
        .execute(db)

    default:
      break
    }
  }

  private func handleAbandonedMediaCleanup(mediaId: String, in db: Database) throws {
    guard let media = try MediaRecord.where({ $0.id.eq(mediaId) }).fetchOne(db) else {
      return
    }
    guard media.isLocalOnly else {
      return
    }

    let localEntryIds =
      try EntryRecord
      .where { $0.mediaId.eq(mediaId) && $0.serverReceivedAt.is(nil) }
      .fetchAll(db)
      .map(\.id)

    try OutboxRepository.deleteUnstartedOperations(
      in: db,
      entityType: .media,
      entityIds: [mediaId]
    )
    try OutboxRepository.deleteUnstartedOperations(
      in: db,
      entityType: .entry,
      entityIds: localEntryIds
    )

    if media.localFilePath != nil {
      let localOnly = MediaSyncState.localOnly.rawValue
      try MediaRecord
        .where { $0.id.eq(mediaId) }
        .update { $0.syncState = localOnly }
        .execute(db)
    } else {
      try MediaRecord
        .where { $0.id.eq(mediaId) }
        .delete()
        .execute(db)
    }
  }
}
