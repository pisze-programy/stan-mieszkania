import CoreGraphics
import Domain
import Foundation

public struct LocalMediaStore: Sendable {
  public let baseDirectory: URL

  public init(baseDirectory: URL) {
    self.baseDirectory = baseDirectory
  }

  public func fileURL(for mediaId: String) -> URL {
    baseDirectory.appendingPathComponent(
      "\(mediaId).\(MediaStorageConstants.jpegFileExtension)"
    )
  }

  // Invariant 1: Compute SHA-256 on final JPEG bytes before atomic write to immutable disk path.
  public func ingestPhoto(_ request: PhotoIngestRequest) throws -> ProcessedPhotoArtifact {
    let processed = try ImageIOProcessor.processPhoto(request: request)
    let sha256 = SHA256Hasher.hexDigest(of: processed.jpegData)
    let targetURL = fileURL(for: request.mediaId)

    try ensureBaseDirectoryExists()
    try processed.jpegData.write(to: targetURL, options: [.atomic])

    return ProcessedPhotoArtifact(
      mediaId: request.mediaId,
      localFilePath: targetURL.path,
      sha256: sha256,
      width: processed.width,
      height: processed.height,
      bytes: processed.jpegData.count,
      capturedAt: processed.metadata.capturedAt,
      capturedTz: processed.metadata.capturedTz,
      capturedAtFromImport: processed.metadata.capturedAtFromImport,
      location: processed.metadata.location
    )
  }

  public func storeRemotePhoto(
    jpegData: Data,
    expectedSha256: String,
    mediaId: String
  ) throws -> String {
    let actualSha256 = SHA256Hasher.hexDigest(of: jpegData)
    let normalizedExpected = expectedSha256.lowercased()
    guard actualSha256 == normalizedExpected else {
      throw MediaStorageError.hashMismatch(
        expected: normalizedExpected,
        actual: actualSha256
      )
    }

    let targetURL = fileURL(for: mediaId)
    try ensureBaseDirectoryExists()
    try jpegData.write(to: targetURL, options: [.atomic])
    return targetURL.path
  }

  public func loadDownsampledThumbnail(mediaId: String, maxPixelSize: Int) throws -> CGImage {
    let targetURL = fileURL(for: mediaId)
    guard FileManager.default.fileExists(atPath: targetURL.path) else {
      throw MediaStorageError.fileNotFound(mediaId: mediaId)
    }
    return try ImageIOProcessor.loadDownsampledThumbnail(
      from: targetURL,
      mediaId: mediaId,
      maxPixelSize: maxPixelSize
    )
  }

  public func loadPhotoData(mediaId: String) throws -> Data {
    let targetURL = fileURL(for: mediaId)
    guard FileManager.default.fileExists(atPath: targetURL.path) else {
      throw MediaStorageError.fileNotFound(mediaId: mediaId)
    }
    return try Data(contentsOf: targetURL)
  }

  public func fileExists(mediaId: String) -> Bool {
    FileManager.default.fileExists(atPath: fileURL(for: mediaId).path)
  }

  public func deleteLocalFile(mediaId: String) throws {
    let targetURL = fileURL(for: mediaId)
    guard FileManager.default.fileExists(atPath: targetURL.path) else {
      return
    }
    try FileManager.default.removeItem(at: targetURL)
  }

  private func ensureBaseDirectoryExists() throws {
    try FileManager.default.createDirectory(
      at: baseDirectory,
      withIntermediateDirectories: true
    )
  }
}
