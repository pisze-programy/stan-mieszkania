import Domain
import Foundation

public enum APISyncMediaUploadStatus: String, Sendable, Equatable, Hashable {
  case pending
  case uploaded
}

public struct APISyncMediaSnapshot: Sendable, Equatable, Hashable {
  public let media: MediaItem
  public let uploadStatus: APISyncMediaUploadStatus
  public let author: AuthorSummary

  public init(media: MediaItem, uploadStatus: APISyncMediaUploadStatus, author: AuthorSummary) {
    self.media = media
    self.uploadStatus = uploadStatus
    self.author = author
  }
}

public struct APISyncEntrySnapshot: Sendable, Equatable, Hashable {
  public let entry: EntryItem
  public let author: AuthorSummary

  public init(entry: EntryItem, author: AuthorSummary) {
    self.entry = entry
    self.author = author
  }
}

public enum APISyncChangePayload: Sendable, Equatable, Hashable {
  case apartment(Apartment)
  case member(ApartmentMember)
  case media(APISyncMediaSnapshot)
  case entry(APISyncEntrySnapshot)
}

public struct APIHydratedSyncChange: Sendable, Equatable, Hashable {
  public let seq: Int
  public let apartmentId: String
  public let entityType: String
  public let entityId: String
  public let op: String
  public let createdAt: Date
  public let payload: APISyncChangePayload?

  public init(
    seq: Int,
    apartmentId: String,
    entityType: String,
    entityId: String,
    op: String,
    createdAt: Date,
    payload: APISyncChangePayload?
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

public struct APISyncChangesPage: Sendable, Equatable, Hashable {
  public let changes: [APIHydratedSyncChange]
  public let nextSeq: Int?
  public let hasMore: Bool

  public init(changes: [APIHydratedSyncChange], nextSeq: Int?, hasMore: Bool) {
    self.changes = changes
    self.nextSeq = nextSeq
    self.hasMore = hasMore
  }
}

public struct APIMyApartmentSyncSummary: Sendable, Equatable, Hashable {
  public let apartment: Apartment
  public let role: MemberRole
  public let headSeq: Int
  public let confirmedMediaCount: Int
  public let latestMediaCapturedAt: Date?

  public init(
    apartment: Apartment,
    role: MemberRole,
    headSeq: Int,
    confirmedMediaCount: Int,
    latestMediaCapturedAt: Date?
  ) {
    self.apartment = apartment
    self.role = role
    self.headSeq = headSeq
    self.confirmedMediaCount = confirmedMediaCount
    self.latestMediaCapturedAt = latestMediaCapturedAt
  }
}
