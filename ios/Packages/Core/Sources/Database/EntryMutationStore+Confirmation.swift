import Domain
import Foundation
import SQLiteData

extension EntryMutationStore {
  // Invariant 3 & S2-3: Synced entries allow only author retraction leaving an audit placeholder.
  public func retractSyncedEntry(
    entryId: String,
    actorId: String,
    outboxId: String = UUIDv7.generateNow(),
    now: Date
  ) throws {
    try database.write { db in
      guard let entry = try EntryRecord.where({ $0.id.eq(entryId) }).fetchOne(db) else {
        throw AppDatabaseError.entryNotFound(entryId)
      }
      guard entry.authorId == actorId else {
        throw AppDatabaseError.entryAuthorMismatch(entryId: entryId, actorId: actorId)
      }
      guard entry.isSynced else {
        throw AppDatabaseError.cannotRetractUnsyncedEntry(entryId)
      }
      guard entry.retractedAt == nil else {
        throw AppDatabaseError.entryAlreadyRetracted(entryId)
      }
      guard let media = try MediaRecord.where({ $0.id.eq(entry.mediaId) }).fetchOne(db) else {
        throw AppDatabaseError.mediaNotFound(entry.mediaId)
      }

      let clearedText = DatabaseConstants.retractedEntryText
      try EntryRecord
        .where { $0.id.eq(entryId) }
        .update {
          $0.text = clearedText
          $0.retractedAt = #bind(now)
        }
        .execute(db)

      try MarkerRecord
        .where { $0.entryId.eq(entryId) }
        .delete()
        .execute(db)

      let payload = RetractEntryOutboxPayload(
        apartmentId: media.apartmentId,
        mediaId: media.id,
        entryId: entryId
      )
      try OutboxRepository.enqueue(
        in: db,
        request: OutboxEnqueueRequest(
          id: outboxId,
          apartmentId: media.apartmentId,
          entityType: .entry,
          entityId: entryId,
          operationType: .retractEntry,
          payload: payload,
          now: now
        )
      )
    }
  }

  // Decision S2-2 & Invariant 5: Confirm entry and renumber markers + [n] tokens in one transaction.
  @discardableResult
  public func confirmEntrySynced(
    entryId: String,
    serverReceivedAt: Date,
    serverMarkers: [MarkerPoint],
    serverText: String? = nil
  ) throws -> EntryRecord {
    try database.write { db in
      guard var entry = try EntryRecord.where({ $0.id.eq(entryId) }).fetchOne(db) else {
        throw AppDatabaseError.entryNotFound(entryId)
      }

      let existingMarkers = try MarkerRecord.where { $0.entryId.eq(entryId) }.fetchAll(db)
      let mapping = buildMarkerNumberMapping(existing: existingMarkers, server: serverMarkers)
      entry.text =
        serverText
        ?? MarkerTextPolicy.rewriteMarkerTokens(
          in: entry.text,
          mapping: mapping
        )
      entry.serverReceivedAt = serverReceivedAt
      try EntryRecord.upsert { entry }.execute(db)

      try replaceConfirmedMarkers(
        entryId: entryId,
        mediaId: entry.mediaId,
        serverMarkers: serverMarkers,
        in: db
      )
      try OutboxRepository.deleteOperations(
        in: db,
        entityType: .entry,
        entityIds: [entryId],
        operationType: .createEntry
      )
      return entry
    }
  }

  private func buildMarkerNumberMapping(
    existing: [MarkerRecord],
    server: [MarkerPoint]
  ) -> [Int: Int] {
    let localNumberByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0.number) })
    var numberMapping: [Int: Int] = [:]
    for marker in server {
      if let localNumber = localNumberByID[marker.id], localNumber != marker.number {
        numberMapping[localNumber] = marker.number
      }
    }
    return numberMapping
  }

  private func replaceConfirmedMarkers(
    entryId: String,
    mediaId: String,
    serverMarkers: [MarkerPoint],
    in db: Database
  ) throws {
    try MarkerRecord.where { $0.entryId.eq(entryId) }.delete().execute(db)
    for marker in serverMarkers {
      let confirmedMarker = MarkerRecord(
        id: marker.id,
        entryId: entryId,
        mediaId: mediaId,
        number: marker.number,
        isServerAssigned: true,
        x: marker.x,
        y: marker.y
      )
      try MarkerRecord.insert { confirmedMarker }.execute(db)
    }
  }
}
