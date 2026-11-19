import Domain
import Foundation
import SQLiteData

extension MediaMutationStore {
  public func markMediaUploading(mediaId: String) throws {
    try database.write { db in
      guard let media = try MediaRecord.where({ $0.id.eq(mediaId) }).fetchOne(db) else {
        throw AppDatabaseError.mediaNotFound(mediaId)
      }
      let allowedStates: Set<String> = [
        MediaSyncState.queued.rawValue,
        MediaSyncState.uploading.rawValue,
      ]
      guard media.isLocalOnly, allowedStates.contains(media.syncState) else {
        throw AppDatabaseError.invalidMediaStateTransition(
          mediaId: mediaId,
          currentState: media.syncState
        )
      }
      let uploading = MediaSyncState.uploading.rawValue
      try MediaRecord
        .where { $0.id.eq(mediaId) }
        .update { $0.syncState = uploading }
        .execute(db)
    }
  }

  public func confirmMediaUploaded(
    mediaId: String,
    serverReceivedAt: Date,
    cloudMediaCount: Int? = nil
  ) throws {
    try database.write { db in
      guard let media = try MediaRecord.where({ $0.id.eq(mediaId) }).fetchOne(db) else {
        throw AppDatabaseError.mediaNotFound(mediaId)
      }
      let verified = MediaSyncState.verified.rawValue
      let clearedDouble: Double? = nil
      let clearedString: String? = nil
      // Decision Q10: Clear local GPS metadata once upload is confirmed in the cloud.
      try MediaRecord
        .where { $0.id.eq(mediaId) }
        .update {
          $0.serverReceivedAt = #bind(serverReceivedAt)
          $0.syncState = verified
          $0.captureLat = #bind(clearedDouble)
          $0.captureLng = #bind(clearedDouble)
          $0.captureAccuracyM = #bind(clearedDouble)
          $0.captureLocationSource = #bind(clearedString)
        }
        .execute(db)

      if let cloudMediaCount {
        try ApartmentRecord
          .where { $0.id.eq(media.apartmentId) }
          .update { $0.cloudMediaCount = cloudMediaCount }
          .execute(db)
      }

      try OutboxRepository.deleteOperations(
        in: db,
        entityType: .media,
        entityIds: [mediaId],
        operationType: .uploadMedia
      )
    }
  }

  // Decision S2-4/5: QUOTA_EXCEEDED reverts queued/uploading media to localOnly without data loss.
  public func handleQuotaExceeded(mediaId: String) throws {
    try database.write { db in
      guard let media = try MediaRecord.where({ $0.id.eq(mediaId) }).fetchOne(db) else {
        throw AppDatabaseError.mediaNotFound(mediaId)
      }
      let revertibleStates: Set<String> = [
        MediaSyncState.queued.rawValue,
        MediaSyncState.uploading.rawValue,
      ]
      guard media.isLocalOnly, revertibleStates.contains(media.syncState) else {
        throw AppDatabaseError.invalidMediaStateTransition(
          mediaId: mediaId,
          currentState: media.syncState
        )
      }

      let localOnly = MediaSyncState.localOnly.rawValue
      try MediaRecord
        .where { $0.id.eq(mediaId) }
        .update { $0.syncState = localOnly }
        .execute(db)

      try OutboxRepository.deleteOperations(
        in: db,
        entityType: .media,
        entityIds: [mediaId],
        operationType: .uploadMedia
      )

      let localEntryIds =
        try EntryRecord
        .where { $0.mediaId.eq(mediaId) && $0.serverReceivedAt.is(nil) }
        .fetchAll(db)
        .map(\.id)

      try OutboxRepository.deleteOperations(
        in: db,
        entityType: .entry,
        entityIds: localEntryIds,
        operationType: .createEntry
      )
    }
  }
}
