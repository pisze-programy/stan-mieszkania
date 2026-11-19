import Domain
import Foundation

enum SyncSchemaMappers: Sendable {
  static func mapChangesResponse(
    _ wire: Components.Schemas.SyncChangesResponse
  ) -> APISyncChangesPage {
    APISyncChangesPage(
      changes: wire.changes.map(mapHydratedChange),
      nextSeq: wire.nextSeq,
      hasMore: wire.hasMore
    )
  }

  static func mapMyApartmentSummary(
    _ wire: Components.Schemas.MyApartmentSyncSummary
  ) -> APIMyApartmentSyncSummary {
    APIMyApartmentSyncSummary(
      apartment: CoreSchemaMappers.mapApartment(wire.apartment),
      role: CoreSchemaMappers.mapRole(wire.role),
      headSeq: wire.headSeq,
      confirmedMediaCount: wire.confirmedMediaCount,
      latestMediaCapturedAt: wire.latestMediaCapturedAt?.value1
    )
  }

  private static func mapHydratedChange(
    _ wire: Components.Schemas.HydratedSyncChange
  ) -> APIHydratedSyncChange {
    let mappedPayload = wire.payload.map { mapPayload($0.value1) }
    return APIHydratedSyncChange(
      seq: wire.seq,
      apartmentId: wire.apartmentId,
      entityType: wire.entityType,
      entityId: wire.entityId,
      op: wire.op,
      createdAt: wire.createdAt,
      payload: mappedPayload
    )
  }

  private static func mapPayload(
    _ wire: Components.Schemas.SyncChangePayload
  ) -> APISyncChangePayload {
    switch wire {
    case .case1(let apartmentCase):
      return .apartment(CoreSchemaMappers.mapApartment(apartmentCase.apartment))
    case .case2(let memberCase):
      return .member(mapSyncMember(memberCase.member))
    case .case3(let mediaCase):
      return .media(mapSyncMedia(mediaCase.media))
    case .case4(let entryCase):
      return .entry(mapSyncEntry(entryCase.entry))
    }
  }

  private static func mapSyncMember(
    _ wire: Components.Schemas.SyncMemberSnapshot
  ) -> ApartmentMember {
    ApartmentMember(
      userId: wire.value1.userId,
      displayName: wire.value1.displayName,
      shortTag: wire.value1.shortTag,
      color: wire.value1.color,
      role: CoreSchemaMappers.mapRole(wire.value1.role),
      joinedAt: wire.value2.joinedAt,
      leftAt: wire.value2.leftAt?.value1
    )
  }

  private static func mapSyncMedia(
    _ wire: Components.Schemas.SyncMediaSnapshot
  ) -> APISyncMediaSnapshot {
    let author = CoreSchemaMappers.mapSyncActor(wire.author)
    let serverReceivedAt = wire.serverReceivedAt?.value1
    let deletedAt = wire.deletedAt?.value1
    let syncState: MediaSyncState
    if deletedAt != nil {
      syncState = .softDeleted
    } else if serverReceivedAt != nil {
      syncState = .verified
    } else {
      syncState = .queued
    }

    let item = MediaItem(
      id: wire.id,
      apartmentId: wire.apartmentId,
      authorId: wire.authorId,
      author: author,
      kind: wire.kind == .photo ? .photo : .video,
      source: wire.source == .camera ? .camera : .imported,
      sha256: wire.sha256,
      capturedAt: wire.capturedAt,
      capturedTz: wire.capturedTz,
      capturedAtFromImport: wire.capturedAtFromImport,
      serverReceivedAt: serverReceivedAt,
      width: wire.width,
      height: wire.height,
      bytes: wire.bytes,
      syncState: syncState,
      deletedAt: deletedAt,
      deletedBy: wire.deletedBy?.value1
    )
    let uploadStatus: APISyncMediaUploadStatus =
      wire.uploadStatus == .uploaded ? .uploaded : .pending
    return APISyncMediaSnapshot(media: item, uploadStatus: uploadStatus, author: author)
  }

  private static func mapSyncEntry(
    _ wire: Components.Schemas.SyncEntrySnapshot
  ) -> APISyncEntrySnapshot {
    let author = CoreSchemaMappers.mapSyncActor(wire.author)
    let item = EntryItem(
      id: wire.id,
      mediaId: wire.mediaId,
      authorId: wire.authorId,
      author: author,
      text: wire.text,
      markers: wire.markers.map(MediaAndEntryMappers.mapMarker),
      createdAt: wire.createdAt,
      serverReceivedAt: wire.serverReceivedAt,
      retractedAt: wire.retractedAt?.value1
    )
    return APISyncEntrySnapshot(entry: item, author: author)
  }
}
