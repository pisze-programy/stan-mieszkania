import APIClient
import Database
import Domain
import Foundation

enum SyncDeltaBridge: Sendable {
  static func toDatabaseChange(_ apiChange: APIHydratedSyncChange) -> HydratedSyncChange {
    HydratedSyncChange(
      seq: apiChange.seq,
      apartmentId: apiChange.apartmentId,
      entityType: apiChange.entityType,
      entityId: apiChange.entityId,
      op: apiChange.op,
      createdAt: apiChange.createdAt,
      payload: apiChange.payload.map(toDatabasePayload)
    )
  }

  private static func toDatabasePayload(_ payload: APISyncChangePayload) -> HydratedSyncPayload {
    switch payload {
    case .apartment(let apartment):
      return .apartment(apartment)
    case .member(let member):
      return .member(member)
    case .media(let mediaSnapshot):
      let media = mediaSnapshot.media
      let status: SyncMediaUploadStatus =
        mediaSnapshot.uploadStatus == .uploaded ? .uploaded : .pending
      return .media(
        HydratedSyncMedia(
          id: media.id,
          apartmentId: media.apartmentId,
          authorId: media.authorId,
          kind: media.kind,
          source: media.source,
          uploadStatus: status,
          sha256: media.sha256,
          capturedAt: media.capturedAt,
          capturedTz: media.capturedTz,
          capturedAtFromImport: media.capturedAtFromImport,
          serverReceivedAt: media.serverReceivedAt,
          width: media.width,
          height: media.height,
          bytes: media.bytes,
          deletedAt: media.deletedAt,
          deletedBy: media.deletedBy,
          author: mediaSnapshot.author
        )
      )
    case .entry(let entrySnapshot):
      let entry = entrySnapshot.entry
      return .entry(
        HydratedSyncEntry(
          id: entry.id,
          mediaId: entry.mediaId,
          authorId: entry.authorId,
          text: entry.text,
          markers: entry.markers,
          createdAt: entry.createdAt,
          serverReceivedAt: entry.serverReceivedAt ?? entry.createdAt,
          retractedAt: entry.retractedAt,
          author: entrySnapshot.author
        )
      )
    }
  }
}
