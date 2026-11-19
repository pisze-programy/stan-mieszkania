import Foundation
import SQLiteData

struct OutboxEnqueueRequest<Payload: Encodable>: Sendable where Payload: Sendable {
  let id: String
  let apartmentId: String
  let entityType: OutboxEntityType
  let entityId: String
  let operationType: OutboxOperationType
  let payload: Payload
  let now: Date
}

public struct OutboxRepository: Sendable {
  let database: any DatabaseWriter

  public init(database: any DatabaseWriter) {
    self.database = database
  }

  public func fetchRunnableOperations(
    asOf now: Date = Date(),
    limit: Int? = nil
  ) throws -> [OutboxOperationRecord] {
    try database.read { db in
      let pending = OutboxOperationStatus.pending.rawValue
      let failed = OutboxOperationStatus.failed.rawValue
      let cutoff: Date? = now
      let baseQuery =
        OutboxOperationRecord
        .where {
          $0.status.eq(pending)
            || ($0.status.eq(failed) && ($0.nextAttemptAt.is(nil) || $0.nextAttemptAt <= cutoff))
        }
        .order { ($0.createdAt.asc(), $0.id.asc()) }

      if let limit {
        return try baseQuery.limit(limit).fetchAll(db)
      }
      return try baseQuery.fetchAll(db)
    }
  }

  public func fetchAllOperations() throws -> [OutboxOperationRecord] {
    try database.read { db in
      try OutboxOperationRecord
        .order { ($0.createdAt.asc(), $0.id.asc()) }
        .fetchAll(db)
    }
  }

  public func markInFlight(id: String, now: Date) throws {
    try database.write { db in
      guard try OutboxOperationRecord.where({ $0.id.eq(id) }).fetchOne(db) != nil else {
        throw AppDatabaseError.outboxOperationNotFound(id)
      }
      let inFlight = OutboxOperationStatus.inFlight.rawValue
      try OutboxOperationRecord
        .where { $0.id.eq(id) }
        .update {
          $0.status = inFlight
          $0.updatedAt = now
        }
        .execute(db)
    }
  }

  public func markSucceeded(id: String) throws {
    try database.write { db in
      try OutboxOperationRecord
        .where { $0.id.eq(id) }
        .delete()
        .execute(db)
    }
  }

  public func markFailed(
    id: String,
    errorCode: String,
    nextAttemptAt: Date?,
    now: Date
  ) throws {
    try database.write { db in
      guard let existing = try OutboxOperationRecord.where({ $0.id.eq(id) }).fetchOne(db) else {
        throw AppDatabaseError.outboxOperationNotFound(id)
      }
      let failed = OutboxOperationStatus.failed.rawValue
      let nextAttemptCount = existing.attemptCount + 1
      try OutboxOperationRecord
        .where { $0.id.eq(id) }
        .update {
          $0.status = failed
          $0.attemptCount = nextAttemptCount
          $0.lastErrorCode = #bind(errorCode)
          $0.nextAttemptAt = #bind(nextAttemptAt)
          $0.updatedAt = now
        }
        .execute(db)
    }
  }

  public func resetInFlightToPending(now: Date) throws {
    try database.write { db in
      let inFlight = OutboxOperationStatus.inFlight.rawValue
      let pending = OutboxOperationStatus.pending.rawValue
      try OutboxOperationRecord
        .where { $0.status.eq(inFlight) }
        .update {
          $0.status = pending
          $0.updatedAt = now
        }
        .execute(db)
    }
  }

  static func enqueue<Payload: Encodable & Sendable>(
    in db: Database,
    request: OutboxEnqueueRequest<Payload>
  ) throws {
    let payloadJson = try OutboxPayloadCodec.encode(request.payload)
    let record = OutboxOperationRecord(
      id: request.id,
      apartmentId: request.apartmentId,
      entityType: request.entityType.rawValue,
      entityId: request.entityId,
      operationType: request.operationType.rawValue,
      payloadJson: payloadJson,
      createdAt: request.now,
      updatedAt: request.now
    )
    try OutboxOperationRecord.insert { record }.execute(db)
  }

  static func deleteUnstartedOperations(
    in db: Database,
    entityType: OutboxEntityType,
    entityIds: [String]
  ) throws {
    guard !entityIds.isEmpty else {
      return
    }
    let inFlight = OutboxOperationStatus.inFlight.rawValue
    let typeRaw = entityType.rawValue
    for entityId in entityIds {
      try OutboxOperationRecord
        .where {
          $0.entityType.eq(typeRaw) && $0.entityId.eq(entityId) && $0.status.neq(inFlight)
        }
        .delete()
        .execute(db)
    }
  }

  static func deleteOperations(
    in db: Database,
    entityType: OutboxEntityType,
    entityIds: [String],
    operationType: OutboxOperationType
  ) throws {
    guard !entityIds.isEmpty else {
      return
    }
    let typeRaw = entityType.rawValue
    let opRaw = operationType.rawValue
    for entityId in entityIds {
      try OutboxOperationRecord
        .where {
          $0.entityType.eq(typeRaw) && $0.entityId.eq(entityId) && $0.operationType.eq(opRaw)
        }
        .delete()
        .execute(db)
    }
  }

  static func deleteOperationsForApartment(in db: Database, apartmentId: String) throws {
    try OutboxOperationRecord
      .where { $0.apartmentId.eq(apartmentId) }
      .delete()
      .execute(db)
  }
}
