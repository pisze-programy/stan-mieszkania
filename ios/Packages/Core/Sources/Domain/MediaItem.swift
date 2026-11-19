import Foundation

public enum MediaKind: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
  case photo
  case video
}

public enum MediaSource: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
  case camera
  case imported = "import"
}

public enum MediaSyncState: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
  case localOnly
  case queued
  case uploading
  case verified
  case softDeleted
}

public enum LocationSource: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
  case device
  case exif
}

// Decision Q10: Capture location is used for upload init only and never displayed in UI.
public struct CaptureLocationMetadata: Codable, Sendable, Equatable, Hashable {
  public let lat: Double
  public let lng: Double
  public let accuracyM: Double?
  public let locationSource: LocationSource

  public init(
    lat: Double,
    lng: Double,
    accuracyM: Double? = nil,
    locationSource: LocationSource
  ) {
    self.lat = lat
    self.lng = lng
    self.accuracyM = accuracyM
    self.locationSource = locationSource
  }
}

public struct MediaItem: Identifiable, Codable, Sendable, Equatable, Hashable {
  public let id: String
  public let apartmentId: String
  public let authorId: String
  public let author: AuthorSummary?
  public let kind: MediaKind
  public let source: MediaSource
  public let sha256: String
  public let capturedAt: Date
  public let capturedTz: String
  public let capturedAtFromImport: Bool
  public var serverReceivedAt: Date?
  public let width: Int
  public let height: Int
  public let bytes: Int
  public var syncState: MediaSyncState
  public var localFilePath: String?
  public var deletedAt: Date?
  public var deletedBy: String?

  // Decision Q2: Verification badge derives strictly from serverReceivedAt != nil.
  public var isVerified: Bool { serverReceivedAt != nil }
  public var isSoftDeleted: Bool { deletedAt != nil }

  public init(
    id: String,
    apartmentId: String,
    authorId: String,
    author: AuthorSummary? = nil,
    kind: MediaKind,
    source: MediaSource,
    sha256: String,
    capturedAt: Date,
    capturedTz: String,
    capturedAtFromImport: Bool,
    serverReceivedAt: Date? = nil,
    width: Int,
    height: Int,
    bytes: Int,
    syncState: MediaSyncState,
    localFilePath: String? = nil,
    deletedAt: Date? = nil,
    deletedBy: String? = nil
  ) {
    self.id = id
    self.apartmentId = apartmentId
    self.authorId = authorId
    self.author = author
    self.kind = kind
    self.source = source
    self.sha256 = sha256
    self.capturedAt = capturedAt
    self.capturedTz = capturedTz
    self.capturedAtFromImport = capturedAtFromImport
    self.serverReceivedAt = serverReceivedAt
    self.width = width
    self.height = height
    self.bytes = bytes
    self.syncState = syncState
    self.localFilePath = localFilePath
    self.deletedAt = deletedAt
    self.deletedBy = deletedBy
  }
}
