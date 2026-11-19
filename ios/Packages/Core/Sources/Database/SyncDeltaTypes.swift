import Domain
import Foundation

public enum SyncMediaUploadStatus: String, Codable, Sendable, Equatable, Hashable {
  case pending
  case uploaded
}

public struct HydratedSyncMedia: Codable, Sendable, Equatable, Hashable {
  public let id: String
  public let apartmentId: String
  public let authorId: String
  public let kind: MediaKind
  public let source: MediaSource
  public let uploadStatus: SyncMediaUploadStatus
  public let sha256: String
  public let capturedAt: Date
  public let capturedTz: String
  public let capturedAtFromImport: Bool
  public let serverReceivedAt: Date?
  public let width: Int
  public let height: Int
  public let bytes: Int
  public let deletedAt: Date?
  public let deletedBy: String?
  public let author: AuthorSummary

  public init(
    id: String,
    apartmentId: String,
    authorId: String,
    kind: MediaKind,
    source: MediaSource,
    uploadStatus: SyncMediaUploadStatus,
    sha256: String,
    capturedAt: Date,
    capturedTz: String,
    capturedAtFromImport: Bool,
    serverReceivedAt: Date?,
    width: Int,
    height: Int,
    bytes: Int,
    deletedAt: Date?,
    deletedBy: String?,
    author: AuthorSummary
  ) {
    self.id = id
    self.apartmentId = apartmentId
    self.authorId = authorId
    self.kind = kind
    self.source = source
    self.uploadStatus = uploadStatus
    self.sha256 = sha256
    self.capturedAt = capturedAt
    self.capturedTz = capturedTz
    self.capturedAtFromImport = capturedAtFromImport
    self.serverReceivedAt = serverReceivedAt
    self.width = width
    self.height = height
    self.bytes = bytes
    self.deletedAt = deletedAt
    self.deletedBy = deletedBy
    self.author = author
  }
}

public struct HydratedSyncEntry: Codable, Sendable, Equatable, Hashable {
  public let id: String
  public let mediaId: String
  public let authorId: String
  public let text: String
  public let markers: [MarkerPoint]
  public let createdAt: Date
  public let serverReceivedAt: Date
  public let retractedAt: Date?
  public let author: AuthorSummary

  public init(
    id: String,
    mediaId: String,
    authorId: String,
    text: String,
    markers: [MarkerPoint],
    createdAt: Date,
    serverReceivedAt: Date,
    retractedAt: Date?,
    author: AuthorSummary
  ) {
    self.id = id
    self.mediaId = mediaId
    self.authorId = authorId
    self.text = text
    self.markers = markers
    self.createdAt = createdAt
    self.serverReceivedAt = serverReceivedAt
    self.retractedAt = retractedAt
    self.author = author
  }
}

public enum HydratedSyncPayload: Sendable, Equatable, Hashable {
  case apartment(Apartment)
  case member(ApartmentMember)
  case media(HydratedSyncMedia)
  case entry(HydratedSyncEntry)
}

public struct HydratedSyncChange: Sendable, Equatable, Hashable {
  public let seq: Int
  public let apartmentId: String
  public let entityType: String
  public let entityId: String
  public let op: String
  public let createdAt: Date
  public let payload: HydratedSyncPayload?

  public init(
    seq: Int,
    apartmentId: String,
    entityType: String,
    entityId: String,
    op: String,
    createdAt: Date,
    payload: HydratedSyncPayload?
  ) {
    self.seq = seq
    self.apartmentId = apartmentId
    self.entityType = entityType
    self.entityId = entityId
    self.op = op
    self.createdAt = createdAt
    self.payload = payload
  }
}
