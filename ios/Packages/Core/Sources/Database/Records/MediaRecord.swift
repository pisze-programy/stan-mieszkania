import Domain
import Foundation
import SQLiteData

@Table("media")
public struct MediaRecord: Identifiable, Equatable, Hashable, Sendable {
  public let id: String
  public let apartmentId: String
  public let authorId: String
  public let kind: String
  public let source: String
  public let sha256: String
  public let capturedAt: Date
  public let capturedTz: String
  public let capturedAtFromImport: Bool
  public var serverReceivedAt: Date?
  public let width: Int
  public let height: Int
  public let bytes: Int
  public var syncState: String
  public var localFilePath: String?
  // Decision Q10: Capture location is stored locally until upload init and never displayed in UI.
  public var captureLat: Double?
  public var captureLng: Double?
  public var captureAccuracyM: Double?
  public var captureLocationSource: String?
  public var deletedAt: Date?
  public var deletedBy: String?

  public var isLocalOnly: Bool { serverReceivedAt == nil }
  public var isSynced: Bool { serverReceivedAt != nil }

  public var captureLocation: CaptureLocationMetadata? {
    guard
      let captureLat,
      let captureLng,
      let captureLocationSource,
      let locationSource = LocationSource(rawValue: captureLocationSource)
    else {
      return nil
    }
    return CaptureLocationMetadata(
      lat: captureLat,
      lng: captureLng,
      accuracyM: captureAccuracyM,
      locationSource: locationSource
    )
  }

  public init(
    id: String,
    apartmentId: String,
    authorId: String,
    kind: String,
    source: String,
    sha256: String,
    capturedAt: Date,
    capturedTz: String,
    capturedAtFromImport: Bool,
    serverReceivedAt: Date? = nil,
    width: Int,
    height: Int,
    bytes: Int,
    syncState: String,
    localFilePath: String? = nil,
    captureLat: Double? = nil,
    captureLng: Double? = nil,
    captureAccuracyM: Double? = nil,
    captureLocationSource: String? = nil,
    deletedAt: Date? = nil,
    deletedBy: String? = nil
  ) {
    self.id = id
    self.apartmentId = apartmentId
    self.authorId = authorId
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
    self.captureLat = captureLat
    self.captureLng = captureLng
    self.captureAccuracyM = captureAccuracyM
    self.captureLocationSource = captureLocationSource
    self.deletedAt = deletedAt
    self.deletedBy = deletedBy
  }

  public init(item: MediaItem, location: CaptureLocationMetadata? = nil) {
    self.init(
      id: item.id,
      apartmentId: item.apartmentId,
      authorId: item.authorId,
      kind: item.kind.rawValue,
      source: item.source.rawValue,
      sha256: item.sha256,
      capturedAt: item.capturedAt,
      capturedTz: item.capturedTz,
      capturedAtFromImport: item.capturedAtFromImport,
      serverReceivedAt: item.serverReceivedAt,
      width: item.width,
      height: item.height,
      bytes: item.bytes,
      syncState: item.syncState.rawValue,
      localFilePath: item.localFilePath,
      captureLat: location?.lat,
      captureLng: location?.lng,
      captureAccuracyM: location?.accuracyM,
      captureLocationSource: location?.locationSource.rawValue,
      deletedAt: item.deletedAt,
      deletedBy: item.deletedBy
    )
  }

  public func toDomain(author: AuthorSummary? = nil) throws -> MediaItem {
    guard let mediaKind = MediaKind(rawValue: kind) else {
      throw AppDatabaseError.invalidStoredEnumValue(column: "media.kind", value: kind)
    }
    guard let mediaSource = MediaSource(rawValue: source) else {
      throw AppDatabaseError.invalidStoredEnumValue(column: "media.source", value: source)
    }
    guard let mediaSyncState = MediaSyncState(rawValue: syncState) else {
      throw AppDatabaseError.invalidStoredEnumValue(column: "media.syncState", value: syncState)
    }
    return MediaItem(
      id: id,
      apartmentId: apartmentId,
      authorId: authorId,
      author: author,
      kind: mediaKind,
      source: mediaSource,
      sha256: sha256,
      capturedAt: capturedAt,
      capturedTz: capturedTz,
      capturedAtFromImport: capturedAtFromImport,
      serverReceivedAt: serverReceivedAt,
      width: width,
      height: height,
      bytes: bytes,
      syncState: mediaSyncState,
      localFilePath: localFilePath,
      deletedAt: deletedAt,
      deletedBy: deletedBy
    )
  }
}
