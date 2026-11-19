import Domain
import Foundation

enum MediaAndEntryMappers: Sendable {
  static func mapPresignedURL(_ wire: Components.Schemas.PresignedUrl) throws -> PresignedURLInfo {
    guard let url = URL(string: wire.url) else {
      throw APIProblemError(
        status: 0,
        code: .unknown("INVALID_URL"),
        title: "Invalid URL",
        detail: APIClientConstants.invalidResponseURLDetail
      )
    }
    return PresignedURLInfo(url: url, expiresAt: wire.expiresAt)
  }

  static func mapMedia(
    _ wire: Components.Schemas.Media,
    author: AuthorSummary? = nil
  ) -> MediaItem {
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

    return MediaItem(
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
  }

  static func mapMediaWithAuthor(
    _ wire: Components.Schemas.MediaWithAuthor
  ) -> MediaItem {
    let author = AuthorSummary(
      userId: wire.value2.author.userId,
      displayName: wire.value2.author.displayName,
      shortTag: wire.value2.author.shortTag,
      color: wire.value2.author.color,
      role: CoreSchemaMappers.mapRole(wire.value2.author.role)
    )
    return mapMedia(wire.value1, author: author)
  }

  static func mapInitMediaResponse(
    _ wire: Components.Schemas.InitMediaUploadResponse
  ) throws -> InitMediaUploadResult {
    let media = mapMedia(wire.media)
    let upload = try wire.upload.map { try mapPresignedURL($0.value1) }
    return InitMediaUploadResult(media: media, upload: upload)
  }

  static func mapMarker(_ wire: Components.Schemas.Marker) -> MarkerPoint {
    MarkerPoint(
      id: wire.id,
      entryId: wire.entryId,
      mediaId: wire.mediaId,
      number: wire.number,
      isServerAssigned: true,
      x: wire.x,
      y: wire.y
    )
  }

  static func mapEntry(_ wire: Components.Schemas.Entry) -> EntryItem {
    let author = AuthorSummary(
      userId: wire.author.userId,
      displayName: wire.author.displayName,
      shortTag: wire.author.shortTag,
      color: wire.author.color,
      role: wire.author.role == .owner ? .owner : .contributor
    )
    return EntryItem(
      id: wire.id,
      mediaId: wire.mediaId,
      authorId: wire.authorId,
      author: author,
      text: wire.text,
      markers: wire.markers.map(mapMarker),
      createdAt: wire.createdAt,
      serverReceivedAt: wire.serverReceivedAt,
      retractedAt: wire.retractedAt?.value1
    )
  }
}
