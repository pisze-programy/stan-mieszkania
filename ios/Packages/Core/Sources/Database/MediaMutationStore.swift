import Domain
import Foundation
import SQLiteData

public struct MediaMutationStore: Sendable {
  let database: any DatabaseWriter

  public init(database: any DatabaseWriter) {
    self.database = database
  }

  public func saveLocalMedia(
    _ item: MediaItem,
    location: CaptureLocationMetadata? = nil,
    initialEntry: EntryItem? = nil,
    queueForCloud: Bool,
    mediaOutboxId: String = UUIDv7.generateNow(),
    entryOutboxId: String = UUIDv7.generateNow(),
    now: Date
  ) throws {
    try database.write { db in
      var mediaItem = item
      mediaItem.serverReceivedAt = nil
      mediaItem.syncState = queueForCloud ? .queued : .localOnly
      let mediaRecord = MediaRecord(item: mediaItem, location: location)
      try MediaRecord.insert { mediaRecord }.execute(db)

      if let initialEntry {
        try insertDraftEntry(initialEntry, in: db)
      }

      guard queueForCloud else {
        return
      }

      try enqueueMediaUpload(
        apartmentId: mediaItem.apartmentId,
        mediaId: mediaItem.id,
        outboxId: mediaOutboxId,
        now: now,
        in: db
      )
      if let initialEntry {
        try enqueueDraftEntryUpload(
          apartmentId: mediaItem.apartmentId,
          entry: initialEntry,
          outboxId: entryOutboxId,
          now: now,
          in: db
        )
      }
    }
  }

  public func queueLocalMediaForCloud(
    mediaId: String,
    mediaOutboxId: String = UUIDv7.generateNow(),
    entryOutboxIDGenerator: @Sendable () -> String = UUIDv7.generateNow,
    now: Date
  ) throws {
    try database.write { db in
      guard let media = try MediaRecord.where({ $0.id.eq(mediaId) }).fetchOne(db) else {
        throw AppDatabaseError.mediaNotFound(mediaId)
      }
      guard media.isLocalOnly, media.syncState == MediaSyncState.localOnly.rawValue else {
        throw AppDatabaseError.invalidMediaStateTransition(
          mediaId: mediaId,
          currentState: media.syncState
        )
      }

      let queuedState = MediaSyncState.queued.rawValue
      try MediaRecord
        .where { $0.id.eq(mediaId) }
        .update { $0.syncState = queuedState }
        .execute(db)

      try enqueueMediaUpload(
        apartmentId: media.apartmentId,
        mediaId: media.id,
        outboxId: mediaOutboxId,
        now: now,
        in: db
      )
      try enqueueLocalEntries(
        for: media,
        outboxIDGenerator: entryOutboxIDGenerator,
        now: now,
        in: db
      )
    }
  }

  private func insertDraftEntry(_ entry: EntryItem, in db: Database) throws {
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
  }

  private func enqueueMediaUpload(
    apartmentId: String,
    mediaId: String,
    outboxId: String,
    now: Date,
    in db: Database
  ) throws {
    try OutboxRepository.enqueue(
      in: db,
      request: OutboxEnqueueRequest(
        id: outboxId,
        apartmentId: apartmentId,
        entityType: .media,
        entityId: mediaId,
        operationType: .uploadMedia,
        payload: UploadMediaOutboxPayload(apartmentId: apartmentId, mediaId: mediaId),
        now: now
      )
    )
  }

  private func enqueueDraftEntryUpload(
    apartmentId: String,
    entry: EntryItem,
    outboxId: String,
    now: Date,
    in db: Database
  ) throws {
    let payload = CreateEntryOutboxPayload(
      apartmentId: apartmentId,
      mediaId: entry.mediaId,
      entryId: entry.id,
      text: entry.text,
      markers: entry.markers
    )
    try OutboxRepository.enqueue(
      in: db,
      request: OutboxEnqueueRequest(
        id: outboxId,
        apartmentId: apartmentId,
        entityType: .entry,
        entityId: entry.id,
        operationType: .createEntry,
        payload: payload,
        now: now
      )
    )
  }

  private func enqueueLocalEntries(
    for media: MediaRecord,
    outboxIDGenerator: @Sendable () -> String,
    now: Date,
    in db: Database
  ) throws {
    let localEntries =
      try EntryRecord
      .where { $0.mediaId.eq(media.id) && $0.serverReceivedAt.is(nil) }
      .order { $0.createdAt.asc() }
      .fetchAll(db)

    for entry in localEntries {
      let markerRecords =
        try MarkerRecord
        .where { $0.entryId.eq(entry.id) }
        .order { $0.number.asc() }
        .fetchAll(db)
      let domainEntry = entry.toDomain(markers: markerRecords.map { $0.toDomain() })
      try enqueueDraftEntryUpload(
        apartmentId: media.apartmentId,
        entry: domainEntry,
        outboxId: outboxIDGenerator(),
        now: now,
        in: db
      )
    }
  }
}
