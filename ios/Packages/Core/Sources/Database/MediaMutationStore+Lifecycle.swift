import Domain
import Foundation
import SQLiteData

extension MediaMutationStore {
  // Invariant 3: Local-only media allows author hard-delete; synced media rejects hard-delete.
  @discardableResult
  public func hardDeleteLocalMedia(mediaId: String, actorId: String) throws -> String? {
    try database.write { db in
      guard let media = try MediaRecord.where({ $0.id.eq(mediaId) }).fetchOne(db) else {
        throw AppDatabaseError.mediaNotFound(mediaId)
      }
      guard media.authorId == actorId else {
        throw AppDatabaseError.mediaAuthorMismatch(mediaId: mediaId, actorId: actorId)
      }
      guard media.isLocalOnly else {
        throw AppDatabaseError.cannotHardDeleteSyncedMedia(mediaId)
      }

      let childEntryIds =
        try EntryRecord
        .where { $0.mediaId.eq(mediaId) }
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
        entityIds: childEntryIds
      )

      try MediaRecord
        .where { $0.id.eq(mediaId) }
        .delete()
        .execute(db)

      return media.localFilePath
    }
  }

  // Invariant 3 & Q3: Synced media allows only author soft-delete with visible tombstone and outbox op.
  public func softDeleteSyncedMedia(
    mediaId: String,
    actorId: String,
    outboxId: String = UUIDv7.generateNow(),
    now: Date
  ) throws {
    try database.write { db in
      guard let media = try MediaRecord.where({ $0.id.eq(mediaId) }).fetchOne(db) else {
        throw AppDatabaseError.mediaNotFound(mediaId)
      }
      guard media.authorId == actorId else {
        throw AppDatabaseError.mediaAuthorMismatch(mediaId: mediaId, actorId: actorId)
      }
      guard media.isSynced else {
        throw AppDatabaseError.cannotSoftDeleteUnsyncedMedia(mediaId)
      }
      guard media.deletedAt == nil else {
        throw AppDatabaseError.mediaAlreadySoftDeleted(mediaId)
      }

      let softDeleted = MediaSyncState.softDeleted.rawValue
      try MediaRecord
        .where { $0.id.eq(mediaId) }
        .update {
          $0.deletedAt = #bind(now)
          $0.deletedBy = #bind(actorId)
          $0.syncState = softDeleted
        }
        .execute(db)

      try OutboxRepository.enqueue(
        in: db,
        request: OutboxEnqueueRequest(
          id: outboxId,
          apartmentId: media.apartmentId,
          entityType: .media,
          entityId: media.id,
          operationType: .softDeleteMedia,
          payload: SoftDeleteMediaOutboxPayload(apartmentId: media.apartmentId, mediaId: media.id),
          now: now
        )
      )
    }
  }
}
