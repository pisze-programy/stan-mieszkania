import Domain
import Foundation
import SQLiteData

public struct EntryMutationStore: Sendable {
  let database: any DatabaseWriter

  public init(database: any DatabaseWriter) {
    self.database = database
  }

  public func createEntry(
    _ entry: EntryItem,
    queueForCloud: Bool,
    outboxId: String = UUIDv7.generateNow(),
    now: Date
  ) throws {
    try database.write { db in
      guard let media = try MediaRecord.where({ $0.id.eq(entry.mediaId) }).fetchOne(db) else {
        throw AppDatabaseError.mediaNotFound(entry.mediaId)
      }

      var draftEntry = entry
      draftEntry.serverReceivedAt = nil
      let entryRecord = EntryRecord(item: draftEntry)
      try EntryRecord.insert { entryRecord }.execute(db)

      for marker in draftEntry.markers {
        var draftMarker = marker
        draftMarker.isServerAssigned = false
        let markerRecord = MarkerRecord(marker: draftMarker)
        try MarkerRecord.insert { markerRecord }.execute(db)
      }

      guard queueForCloud else {
        return
      }

      let payload = CreateEntryOutboxPayload(
        apartmentId: media.apartmentId,
        mediaId: media.id,
        entryId: entry.id,
        text: draftEntry.text,
        markers: draftEntry.markers
      )
      try OutboxRepository.enqueue(
        in: db,
        request: OutboxEnqueueRequest(
          id: outboxId,
          apartmentId: media.apartmentId,
          entityType: .entry,
          entityId: entry.id,
          operationType: .createEntry,
          payload: payload,
          now: now
        )
      )
    }
  }

  // Invariant 3 & S2-3: Local-only entries allow editing text and markers; synced entries are immutable.
  public func updateLocalEntry(
    entryId: String,
    actorId: String,
    text: String,
    markers: [MarkerPoint],
    now: Date
  ) throws {
    try database.write { db in
      guard let entry = try EntryRecord.where({ $0.id.eq(entryId) }).fetchOne(db) else {
        throw AppDatabaseError.entryNotFound(entryId)
      }
      guard entry.authorId == actorId else {
        throw AppDatabaseError.entryAuthorMismatch(entryId: entryId, actorId: actorId)
      }
      guard entry.isLocalOnly else {
        throw AppDatabaseError.cannotEditSyncedEntry(entryId)
      }

      try EntryRecord
        .where { $0.id.eq(entryId) }
        .update { $0.text = text }
        .execute(db)

      try MarkerRecord
        .where { $0.entryId.eq(entryId) }
        .delete()
        .execute(db)

      for marker in markers {
        var draftMarker = marker
        draftMarker.isServerAssigned = false
        let markerRecord = MarkerRecord(marker: draftMarker)
        try MarkerRecord.insert { markerRecord }.execute(db)
      }

      if let media = try MediaRecord.where({ $0.id.eq(entry.mediaId) }).fetchOne(db) {
        let createEntryOp = OutboxOperationType.createEntry.rawValue
        let inFlight = OutboxOperationStatus.inFlight.rawValue
        let payloadJson = try OutboxPayloadCodec.encode(
          CreateEntryOutboxPayload(
            apartmentId: media.apartmentId,
            mediaId: media.id,
            entryId: entryId,
            text: text,
            markers: markers
          )
        )
        try OutboxOperationRecord
          .where {
            $0.entityId.eq(entryId)
              && $0.operationType.eq(createEntryOp)
              && $0.status.neq(inFlight)
          }
          .update {
            $0.payloadJson = payloadJson
            $0.updatedAt = now
          }
          .execute(db)
      }
    }
  }

  // Invariant 3 & S2-3: Local-only entries allow author hard-delete; synced entries reject hard-delete.
  public func hardDeleteLocalEntry(entryId: String, actorId: String) throws {
    try database.write { db in
      guard let entry = try EntryRecord.where({ $0.id.eq(entryId) }).fetchOne(db) else {
        throw AppDatabaseError.entryNotFound(entryId)
      }
      guard entry.authorId == actorId else {
        throw AppDatabaseError.entryAuthorMismatch(entryId: entryId, actorId: actorId)
      }
      guard entry.isLocalOnly else {
        throw AppDatabaseError.cannotHardDeleteSyncedEntry(entryId)
      }

      try OutboxRepository.deleteUnstartedOperations(
        in: db,
        entityType: .entry,
        entityIds: [entryId]
      )
      try EntryRecord
        .where { $0.id.eq(entryId) }
        .delete()
        .execute(db)
    }
  }
}
