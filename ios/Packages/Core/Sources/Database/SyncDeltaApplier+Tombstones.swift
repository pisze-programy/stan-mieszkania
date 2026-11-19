import Domain
import Foundation
import SQLiteData

extension SyncDeltaApplier {
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
}
