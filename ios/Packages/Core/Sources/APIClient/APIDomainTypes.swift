import Domain
import Foundation

public struct UpsertApartmentInput: Sendable, Equatable {
  public let apartmentId: String
  public let name: String
  public let street: String
  public let city: String

  public init(apartmentId: String, name: String, street: String, city: String) {
    self.apartmentId = apartmentId
    self.name = name
    self.street = street
    self.city = city
  }
}

public struct UpdateApartmentInput: Sendable, Equatable {
  public let apartmentId: String
  public let name: String?
  public let street: String?
  public let city: String?

  public init(
    apartmentId: String,
    name: String? = nil,
    street: String? = nil,
    city: String? = nil
  ) {
    self.apartmentId = apartmentId
    self.name = name
    self.street = street
    self.city = city
  }
}

public struct InitMediaUploadInput: Sendable, Equatable {
  public let apartmentId: String
  public let mediaId: String
  public let kind: MediaKind
  public let source: MediaSource
  public let sha256: String
  public let capturedAt: Date
  public let capturedTz: String
  public let capturedAtFromImport: Bool
  public let width: Int
  public let height: Int
  public let bytes: Int
  public let location: CaptureLocationMetadata?

  public init(
    apartmentId: String,
    mediaId: String,
    kind: MediaKind = .photo,
    source: MediaSource,
    sha256: String,
    capturedAt: Date,
    capturedTz: String,
    capturedAtFromImport: Bool,
    width: Int,
    height: Int,
    bytes: Int,
    location: CaptureLocationMetadata? = nil
  ) {
    self.apartmentId = apartmentId
    self.mediaId = mediaId
    self.kind = kind
    self.source = source
    self.sha256 = sha256
    self.capturedAt = capturedAt
    self.capturedTz = capturedTz
    self.capturedAtFromImport = capturedAtFromImport
    self.width = width
    self.height = height
    self.bytes = bytes
    self.location = location
  }
}

public struct PresignedURLInfo: Sendable, Equatable, Hashable {
  public let url: URL
  public let expiresAt: Date

  public init(url: URL, expiresAt: Date) {
    self.url = url
    self.expiresAt = expiresAt
  }
}

public struct InitMediaUploadResult: Sendable, Equatable {
  public let media: MediaItem
  public let upload: PresignedURLInfo?

  public init(media: MediaItem, upload: PresignedURLInfo?) {
    self.media = media
    self.upload = upload
  }
}

public struct MediaTimelinePage: Sendable, Equatable {
  public let items: [MediaItem]
  public let nextCursor: String?
  public let hasMore: Bool

  public init(items: [MediaItem], nextCursor: String?, hasMore: Bool) {
    self.items = items
    self.nextCursor = nextCursor
    self.hasMore = hasMore
  }
}

public struct DraftMarkerInput: Sendable, Equatable, Hashable {
  public let id: String
  public let localNumber: Int
  public let x: Double
  public let y: Double

  public init(id: String, localNumber: Int, x: Double, y: Double) {
    self.id = id
    self.localNumber = localNumber
    self.x = x
    self.y = y
  }
}

public struct PutMediaEntryInput: Sendable, Equatable {
  public let apartmentId: String
  public let mediaId: String
  public let entryId: String
  public let text: String
  public let createdAt: Date
  public let markers: [DraftMarkerInput]

  public init(
    apartmentId: String,
    mediaId: String,
    entryId: String,
    text: String,
    createdAt: Date,
    markers: [DraftMarkerInput] = []
  ) {
    self.apartmentId = apartmentId
    self.mediaId = mediaId
    self.entryId = entryId
    self.text = text
    self.createdAt = createdAt
    self.markers = markers
  }
}
