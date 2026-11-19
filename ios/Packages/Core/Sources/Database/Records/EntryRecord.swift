import Domain
import Foundation
import SQLiteData

@Table("entries")
public struct EntryRecord: Identifiable, Equatable, Hashable, Sendable {
  public let id: String
  public let mediaId: String
  public let authorId: String
  public var text: String
  public let createdAt: Date
  public var serverReceivedAt: Date?
  public var retractedAt: Date?

  public var isLocalOnly: Bool { serverReceivedAt == nil }
  public var isSynced: Bool { serverReceivedAt != nil }

  public init(
    id: String,
    mediaId: String,
    authorId: String,
    text: String,
    createdAt: Date,
    serverReceivedAt: Date? = nil,
    retractedAt: Date? = nil
  ) {
    self.id = id
    self.mediaId = mediaId
    self.authorId = authorId
    self.text = text
    self.createdAt = createdAt
    self.serverReceivedAt = serverReceivedAt
    self.retractedAt = retractedAt
  }

  public init(item: EntryItem) {
    self.init(
      id: item.id,
      mediaId: item.mediaId,
      authorId: item.authorId,
      text: item.text,
      createdAt: item.createdAt,
      serverReceivedAt: item.serverReceivedAt,
      retractedAt: item.retractedAt
    )
  }

  public func toDomain(
    markers: [MarkerPoint] = [],
    author: AuthorSummary? = nil
  ) -> EntryItem {
    EntryItem(
      id: id,
      mediaId: mediaId,
      authorId: authorId,
      author: author,
      text: text,
      markers: markers,
      createdAt: createdAt,
      serverReceivedAt: serverReceivedAt,
      retractedAt: retractedAt
    )
  }
}

@Table("markers")
public struct MarkerRecord: Identifiable, Equatable, Hashable, Sendable {
  public let id: String
  public let entryId: String
  public let mediaId: String
  public var number: Int
  public var isServerAssigned: Bool
  public let x: Double
  public let y: Double

  public init(
    id: String,
    entryId: String,
    mediaId: String,
    number: Int,
    isServerAssigned: Bool,
    x: Double,
    y: Double
  ) {
    self.id = id
    self.entryId = entryId
    self.mediaId = mediaId
    self.number = number
    self.isServerAssigned = isServerAssigned
    self.x = x
    self.y = y
  }

  public init(marker: MarkerPoint) {
    self.init(
      id: marker.id,
      entryId: marker.entryId,
      mediaId: marker.mediaId,
      number: marker.number,
      isServerAssigned: marker.isServerAssigned,
      x: marker.x,
      y: marker.y
    )
  }

  public func toDomain() -> MarkerPoint {
    MarkerPoint(
      id: id,
      entryId: entryId,
      mediaId: mediaId,
      number: number,
      isServerAssigned: isServerAssigned,
      x: x,
      y: y
    )
  }
}
