import Foundation

public enum CaptureSourceKind: String, Equatable, Hashable, Sendable, CaseIterable {
  case camera
  case photoLibrary
  case files

  public var mediaSource: MediaSource {
    switch self {
    case .camera:
      return .camera
    case .photoLibrary, .files:
      return .imported
    }
  }
}

public struct CapturedPhotoDraft: Identifiable, Equatable, Hashable, Sendable {
  public let id: String
  public let apartmentId: String
  public let origin: CaptureSourceKind
  public let source: MediaSource
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
    id: String,
    apartmentId: String,
    origin: CaptureSourceKind,
    source: MediaSource,
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
    self.id = id
    self.apartmentId = apartmentId
    self.origin = origin
    self.source = source
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
