import APIClient
import Database
import Domain
import Foundation
import SQLiteData

extension SyncEngineActor {
  func executeCreateEntry(
    _ operation: OutboxOperationRecord
  ) async throws -> OperationExecutionOutcome {
    let payload = try operation.decodePayload(CreateEntryOutboxPayload.self)
    guard
      let mediaRecord = try await database.read({ db in
        try MediaRecord.where { $0.id.eq(payload.mediaId) }.fetchOne(db)
      })
    else {
      throw SyncEngineError.mediaNotFound(mediaId: payload.mediaId)
    }

    if let earlyOutcome = try evaluateParentMediaReadiness(mediaRecord) {
      return earlyOutcome
    }

    guard
      let entryRecord = try await database.read({ db in
        try EntryRecord.where { $0.id.eq(payload.entryId) }.fetchOne(db)
      })
    else {
      throw SyncEngineError.entryNotFound(entryId: payload.entryId)
    }

    let localMarkers = try await database.read { db in
      try MarkerRecord
        .where { $0.entryId.eq(payload.entryId) }
        .order { $0.number.asc() }
        .fetchAll(db)
    }
    let draftMarkers = localMarkers.map {
      DraftMarkerInput(id: $0.id, localNumber: $0.number, x: $0.x, y: $0.y)
    }

    let confirmedEntry = try await apiClient.putMediaEntry(
      PutMediaEntryInput(
        apartmentId: payload.apartmentId,
        mediaId: payload.mediaId,
        entryId: payload.entryId,
        text: entryRecord.text,
        createdAt: entryRecord.createdAt,
        markers: draftMarkers
      )
    )

    let entryStore = EntryMutationStore(database: database)
    try entryStore.confirmEntrySynced(
      entryId: payload.entryId,
      serverReceivedAt: confirmedEntry.serverReceivedAt ?? clock(),
      serverMarkers: confirmedEntry.markers,
      serverText: confirmedEntry.text
    )
    return .succeeded
  }

  private func evaluateParentMediaReadiness(
    _ mediaRecord: MediaRecord
  ) throws -> OperationExecutionOutcome? {
    // Invariant 7: Drop unachievable entry uploads for soft-deleted or unqueued localOnly media.
    if mediaRecord.deletedAt != nil {
      return .dropped
    }
    if !mediaRecord.isSynced {
      let outbox = OutboxRepository(database: database)
      let hasUploadOp = try outbox.hasOperation(
        entityType: .media,
        entityId: mediaRecord.id,
        operationType: .uploadMedia
      )
      if mediaRecord.syncState == MediaSyncState.localOnly.rawValue && !hasUploadOp {
        return .dropped
      }
      return .deferred
    }
    return nil
  }
}
