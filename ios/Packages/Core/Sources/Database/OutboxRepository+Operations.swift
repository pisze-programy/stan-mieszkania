import Foundation
import SQLiteData

extension OutboxRepository {
  public func resetToPending(id: String, now: Date) throws {
    try database.write { db in
      let pending = OutboxOperationStatus.pending.rawValue
      try OutboxOperationRecord
        .where { $0.id.eq(id) }
        .update {
          $0.status = pending
          $0.updatedAt = now
        }
        .execute(db)
    }
  }

  public func hasOperation(
    entityType: OutboxEntityType,
    entityId: String,
    operationType: OutboxOperationType
  ) throws -> Bool {
    try database.read { db in
      let typeRaw = entityType.rawValue
      let opRaw = operationType.rawValue
      let match =
        try OutboxOperationRecord
        .where {
          $0.entityType.eq(typeRaw) && $0.entityId.eq(entityId) && $0.operationType.eq(opRaw)
        }
        .fetchOne(db)
      return match != nil
    }
  }
}
