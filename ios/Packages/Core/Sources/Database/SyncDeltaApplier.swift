import Domain
import Foundation
import SQLiteData

public struct SyncDeltaApplier: Sendable {
  let database: any DatabaseWriter

  public init(database: any DatabaseWriter) {
    self.database = database
  }

  public func fetchLastSeq(apartmentId: String) throws -> Int {
    try database.read { db in
      try SyncCursorRecord
        .where { $0.apartmentId.eq(apartmentId) }
        .fetchOne(db)?
        .lastSeq ?? DatabaseConstants.initialSyncCursorSeq
    }
  }

  public func applyHydratedChange(_ change: HydratedSyncChange, now: Date) throws {
    try applyHydratedChanges([change], now: now)
  }

  public func applyHydratedChanges(_ changes: [HydratedSyncChange], now: Date) throws {
    guard !changes.isEmpty else {
      return
    }
    try database.write { db in
      for change in changes {
        try applySingleChange(change, now: now, in: db)
      }
    }
  }

  private func applySingleChange(
    _ change: HydratedSyncChange,
    now: Date,
    in db: Database
  ) throws {
    guard change.seq >= DatabaseConstants.initialSyncCursorSeq else {
      throw AppDatabaseError.invalidSyncChange("Negative sequence \(change.seq)")
    }

    let currentLastSeq =
      try SyncCursorRecord
      .where { $0.apartmentId.eq(change.apartmentId) }
      .fetchOne(db)?
      .lastSeq ?? DatabaseConstants.initialSyncCursorSeq

    if change.seq <= currentLastSeq {
      return
    }

    if let payload = change.payload {
      try applyPayload(payload, change: change, in: db)
    } else {
      try applyTombstone(change, in: db)
    }

    if try ApartmentRecord.where({ $0.id.eq(change.apartmentId) }).fetchOne(db) != nil {
      let cursor = SyncCursorRecord(
        apartmentId: change.apartmentId,
        lastSeq: change.seq,
        updatedAt: now
      )
      try SyncCursorRecord.upsert { cursor }.execute(db)
    }
  }

  private func applyPayload(
    _ payload: HydratedSyncPayload,
    change: HydratedSyncChange,
    in db: Database
  ) throws {
    switch payload {
    case .apartment(let apartment):
      let deletedAt = change.op == DatabaseConstants.SyncOperation.deleted ? change.createdAt : nil
      let record = ApartmentRecord(apartment: apartment, deletedAt: deletedAt)
      try ApartmentRecord.upsert { record }.execute(db)
      if deletedAt != nil {
        try OutboxRepository.deleteOperationsForApartment(in: db, apartmentId: apartment.id)
      }

    case .member(let member):
      let record = MemberRecord(apartmentId: change.apartmentId, member: member)
      try MemberRecord.upsert { record }.execute(db)

    case .media(let media):
      try applyMediaSnapshot(media, in: db)

    case .entry(let entry):
      try applyEntrySnapshot(entry, apartmentId: change.apartmentId, in: db)
    }
  }

  private func applyMediaSnapshot(_ media: HydratedSyncMedia, in db: Database) throws {
    try upsertAuthorMember(
      media.author,
      apartmentId: media.apartmentId,
      fallbackJoinedAt: media.capturedAt,
      in: db
    )
    let existing = try MediaRecord.where({ $0.id.eq(media.id) }).fetchOne(db)
    let derivedState: MediaSyncState
    if media.deletedAt != nil {
      derivedState = .softDeleted
    } else if media.serverReceivedAt != nil {
      derivedState = .verified
    } else {
      derivedState = .queued
    }

    let record = MediaRecord(
      id: media.id,
      apartmentId: media.apartmentId,
      authorId: media.authorId,
      kind: media.kind.rawValue,
      source: media.source.rawValue,
      sha256: media.sha256,
      capturedAt: media.capturedAt,
      capturedTz: media.capturedTz,
      capturedAtFromImport: media.capturedAtFromImport,
      serverReceivedAt: media.serverReceivedAt,
      width: media.width,
      height: media.height,
      bytes: media.bytes,
      syncState: derivedState.rawValue,
      localFilePath: existing?.localFilePath,
      captureLat: media.serverReceivedAt == nil ? existing?.captureLat : nil,
      captureLng: media.serverReceivedAt == nil ? existing?.captureLng : nil,
      captureAccuracyM: media.serverReceivedAt == nil ? existing?.captureAccuracyM : nil,
      captureLocationSource: media.serverReceivedAt == nil ? existing?.captureLocationSource : nil,
      deletedAt: media.deletedAt,
      deletedBy: media.deletedBy
    )
    try MediaRecord.upsert { record }.execute(db)
  }

  private func applyEntrySnapshot(
    _ entry: HydratedSyncEntry,
    apartmentId: String,
    in db: Database
  ) throws {
    try upsertAuthorMember(
      entry.author,
      apartmentId: apartmentId,
      fallbackJoinedAt: entry.createdAt,
      in: db
    )
    // Decision S2-3: Retracted entries mask text and remove markers locally as well.
    let maskedText = entry.retractedAt != nil ? DatabaseConstants.retractedEntryText : entry.text
    let record = EntryRecord(
      id: entry.id,
      mediaId: entry.mediaId,
      authorId: entry.authorId,
      text: maskedText,
      createdAt: entry.createdAt,
      serverReceivedAt: entry.serverReceivedAt,
      retractedAt: entry.retractedAt
    )
    try EntryRecord.upsert { record }.execute(db)

    try MarkerRecord
      .where { $0.entryId.eq(entry.id) }
      .delete()
      .execute(db)

    guard entry.retractedAt == nil else {
      return
    }

    for marker in entry.markers {
      let markerRecord = MarkerRecord(
        id: marker.id,
        entryId: entry.id,
        mediaId: entry.mediaId,
        number: marker.number,
        isServerAssigned: true,
        x: marker.x,
        y: marker.y
      )
      try MarkerRecord.insert { markerRecord }.execute(db)
    }
  }
}
