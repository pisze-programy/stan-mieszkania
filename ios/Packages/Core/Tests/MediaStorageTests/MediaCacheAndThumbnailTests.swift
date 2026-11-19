import Dependencies
import Domain
import Foundation
import ImageIO
import MediaStorage
import Testing

@Suite("Media Disk Cache, Remote Hash Verification, and Thumbnail Downsampling Tests")
struct MediaCacheAndThumbnailTests {
  @Test("Verifies SHA-256 on remote photo storage and rejects corrupted payloads")
  func remotePhotoHashVerificationAndRejection() throws {
    let tempDir = makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let client = MediaStorageClient.live(baseDirectory: tempDir)

    let jpegData = try SyntheticImageFixtures.makeSyntheticJpegData(
      width: SyntheticImageFixtures.mediumWidth,
      height: SyntheticImageFixtures.mediumHeight,
      includeExifAndGps: false
    )
    let validSha = SHA256Hasher.hexDigest(of: jpegData)
    let wrongSha = String(repeating: "0", count: ContractConstants.sha256HexLength)

    #expect(throws: MediaStorageError.hashMismatch(expected: wrongSha, actual: validSha)) {
      try client.storeRemotePhoto(jpegData, wrongSha, SyntheticImageFixtures.remoteMediaId)
    }
    #expect(!client.fileExists(SyntheticImageFixtures.remoteMediaId))

    let storedPath = try client.storeRemotePhoto(
      jpegData,
      validSha.uppercased(),
      SyntheticImageFixtures.remoteMediaId
    )
    #expect(client.fileExists(SyntheticImageFixtures.remoteMediaId))
    #expect(FileManager.default.fileExists(atPath: storedPath))
    #expect(try client.loadPhotoData(SyntheticImageFixtures.remoteMediaId) == jpegData)

    try client.deleteLocalFile(SyntheticImageFixtures.remoteMediaId)
    #expect(!client.fileExists(SyntheticImageFixtures.remoteMediaId))
  }

  @Test("Downsamples cached photo to thumbnail within maxPixelSize via DependencyValues")
  func downsampledThumbnailAndDependencyClient() throws {
    let tempDir = makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let jpegData = try SyntheticImageFixtures.makeSyntheticJpegData(
      width: SyntheticImageFixtures.mediumWidth,
      height: SyntheticImageFixtures.mediumHeight,
      includeExifAndGps: false
    )

    try withDependencies {
      $0.mediaStorage = .live(baseDirectory: tempDir)
    } operation: {
      @Dependency(\.mediaStorage) var mediaStorage

      _ = try mediaStorage.ingestPhoto(
        PhotoIngestRequest(
          mediaId: SyntheticImageFixtures.mediaId,
          rawData: jpegData,
          source: .camera,
          now: SyntheticImageFixtures.sampleNow
        )
      )

      let thumbnail = try mediaStorage.loadDownsampledThumbnail(
        SyntheticImageFixtures.mediaId,
        SyntheticImageFixtures.thumbnailMaxSize
      )
      #expect(thumbnail.width == SyntheticImageFixtures.thumbnailMaxSize)
      #expect(thumbnail.height == SyntheticImageFixtures.expectedThumbnailHeight)
    }
  }

  @Test("Applies EXIF orientation transform during ingest and resets output orientation to up")
  func appliesOrientationTransformOnIngest() throws {
    let tempDir = makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let store = LocalMediaStore(baseDirectory: tempDir)

    let rotatedRaw = try SyntheticImageFixtures.makeSyntheticJpegData(
      width: SyntheticImageFixtures.mediumWidth,
      height: SyntheticImageFixtures.mediumHeight,
      includeExifAndGps: false,
      orientation: SyntheticImageFixtures.orientationRight
    )
    let artifact = try store.ingestPhoto(
      PhotoIngestRequest(
        mediaId: SyntheticImageFixtures.mediaId,
        rawData: rotatedRaw,
        source: .camera,
        now: SyntheticImageFixtures.sampleNow
      )
    )

    #expect(artifact.width == SyntheticImageFixtures.mediumHeight)
    #expect(artifact.height == SyntheticImageFixtures.mediumWidth)

    let savedProps = SyntheticImageFixtures.readImageProperties(
      from: try store.loadPhotoData(mediaId: SyntheticImageFixtures.mediaId)
    )
    let savedOrientation = (savedProps[kCGImagePropertyOrientation] as? NSNumber)?.intValue
    #expect(savedOrientation == MediaStorageConstants.cgOrientationUp)
  }

  private func makeTempDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString,
      isDirectory: true
    )
  }
}
