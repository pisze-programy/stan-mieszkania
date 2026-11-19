import Foundation

public struct MarkerPoint: Identifiable, Codable, Sendable, Equatable, Hashable {
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
}

public struct EntryItem: Identifiable, Codable, Sendable, Equatable, Hashable {
  public let id: String
  public let mediaId: String
  public let authorId: String
  public let author: AuthorSummary?
  public var text: String
  public var markers: [MarkerPoint]
  public let createdAt: Date
  public var serverReceivedAt: Date?
  public var retractedAt: Date?

  // Decision Q2: Verification badge derives strictly from serverReceivedAt != nil.
  public var isVerified: Bool { serverReceivedAt != nil }
  public var isRetracted: Bool { retractedAt != nil }

  public init(
    id: String,
    mediaId: String,
    authorId: String,
    author: AuthorSummary? = nil,
    text: String,
    markers: [MarkerPoint] = [],
    createdAt: Date,
    serverReceivedAt: Date? = nil,
    retractedAt: Date? = nil
  ) {
    self.id = id
    self.mediaId = mediaId
    self.authorId = authorId
    self.author = author
    self.text = text
    self.markers = markers
    self.createdAt = createdAt
    self.serverReceivedAt = serverReceivedAt
    self.retractedAt = retractedAt
  }
}
