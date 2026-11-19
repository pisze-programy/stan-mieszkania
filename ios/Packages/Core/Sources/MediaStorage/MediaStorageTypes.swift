import Domain
import Foundation

public enum MediaStorageError: Error, Equatable, Sendable {
  case invalidImageData
  case encodingFailed
  case exceedsMaxBytes(actualBytes: Int, maxBytes: Int)
  case hashMismatch(expected: String, actual: String)
  case fileNotFound(mediaId: String)
  case thumbnailGenerationFailed(mediaId: String)
  case invalidConfiguration(String)
}

public struct PhotoIngestRequest: Sendable, Equatable {
  public let mediaId: String
  public let rawData: Data
  public let source: MediaSource
  public let compression: JpegCompressionSettings
  public let deviceLocation: CaptureLocationMetadata?
  public let now: Date
  public let timeZoneIdentifier: String

  public init(
    mediaId: String,
    rawData: Data,
    source: MediaSource,
    compression: JpegCompressionSettings = .fallbackDefaults,
    deviceLocation: CaptureLocationMetadata? = nil,
    now: Date = Date(),
    timeZoneIdentifier: String = TimeZone.current.identifier
  ) {
    self.mediaId = mediaId
    self.rawData = rawData
    self.source = source
    self.compression = compression
    self.deviceLocation = deviceLocation
    self.now = now
    self.timeZoneIdentifier = timeZoneIdentifier
  }
}

public struct ProcessedPhotoArtifact: Sendable, Equatable {
  public let mediaId: String
  public let localFilePath: String
  public let sha256: String
  public let width: Int
  public let height: Int
  public let bytes: Int
  public let capturedAt: Date
  public let capturedTz: String
  public let capturedAtFromImport: Bool
  public let location: CaptureLocationMetadata?

  public init(
    mediaId: String,
    localFilePath: String,
    sha256: String,
    width: Int,
    height: Int,
    bytes: Int,
    capturedAt: Date,
    capturedTz: String,
    capturedAtFromImport: Bool,
    location: CaptureLocationMetadata?
  ) {
    self.mediaId = mediaId
    self.localFilePath = localFilePath
    self.sha256 = sha256
    self.width = width
    self.height = height
    self.bytes = bytes
    self.capturedAt = capturedAt
    self.capturedTz = capturedTz
    self.capturedAtFromImport = capturedAtFromImport
    self.location = location
  }
}
