import Domain
import Foundation
import ImageIO
import MediaStorage
import Testing

@Suite("Media Ingestion, EXIF Preservation, and Compression Tests")
struct MediaIngestionAndExifTests {
  @Test("Scales 4000x3000 to 3000x2250, preserves EXIF and GPS, and matches SHA-256 on disk")
  func scalesProportionallyAndPreservesExifAndGps() throws {
    let tempDir = makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let store = LocalMediaStore(baseDirectory: tempDir)

    let rawData = try SyntheticImageFixtures.makeSyntheticJpegData(
      width: SyntheticImageFixtures.largeWidth,
      height: SyntheticImageFixtures.largeHeight,
      includeExifAndGps: true
    )
    let artifact = try store.ingestPhoto(
      PhotoIngestRequest(
        mediaId: SyntheticImageFixtures.mediaId,
        rawData: rawData,
        source: .imported,
        now: SyntheticImageFixtures.sampleNow,
        timeZoneIdentifier: SyntheticImageFixtures.warsawTimeZone
      )
    )

    #expect(artifact.width == SyntheticImageFixtures.expectedScaledWidth)
    #expect(artifact.height == SyntheticImageFixtures.expectedScaledHeight)
    #expect(artifact.bytes <= ContractConstants.defaultJpegMaxBytes)
    #expect(artifact.sha256.count == ContractConstants.sha256HexLength)
    #expect(!artifact.capturedAtFromImport)
    #expect(artifact.capturedTz == SyntheticImageFixtures.exifOffsetOriginal)

    let location = try #require(artifact.location)
    #expect(location.locationSource == .exif)
    #expect(
      abs(location.lat - SyntheticImageFixtures.warsawLat) < SyntheticImageFixtures.coordTolerance)
    #expect(
      abs(location.lng - SyntheticImageFixtures.warsawLng) < SyntheticImageFixtures.coordTolerance)

    let storedData = try store.loadPhotoData(mediaId: SyntheticImageFixtures.mediaId)
    #expect(storedData.count == artifact.bytes)
    #expect(SHA256Hasher.hexDigest(of: storedData) == artifact.sha256)

    let savedProps = SyntheticImageFixtures.readImageProperties(from: storedData)
    let exif = try #require(savedProps[kCGImagePropertyExifDictionary] as? [CFString: Any])
    let tiff = try #require(savedProps[kCGImagePropertyTIFFDictionary] as? [CFString: Any])
    let gps = try #require(savedProps[kCGImagePropertyGPSDictionary] as? [CFString: Any])

    #expect(
      exif[kCGImagePropertyExifDateTimeOriginal] as? String
        == SyntheticImageFixtures.exifDateOriginal)
    #expect(
      exif[kCGImagePropertyExifOffsetTimeOriginal] as? String
        == SyntheticImageFixtures.exifOffsetOriginal
    )
    #expect(tiff[kCGImagePropertyTIFFMake] as? String == SyntheticImageFixtures.cameraMake)
    #expect(tiff[kCGImagePropertyTIFFModel] as? String == SyntheticImageFixtures.cameraModel)
    #expect(gps[kCGImagePropertyGPSLatitude] != nil)
    #expect(gps[kCGImagePropertyGPSLongitude] != nil)
  }

  @Test("Steps JPEG quality down to satisfy maxBytes cap and rejects impossible byte limits")
  func stepsDownQualityToRespectMaxBytes() throws {
    let tempDir = makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let store = LocalMediaStore(baseDirectory: tempDir)

    let rawData = try SyntheticImageFixtures.makeSyntheticJpegData(
      width: SyntheticImageFixtures.mediumWidth,
      height: SyntheticImageFixtures.mediumHeight,
      includeExifAndGps: false
    )

    let tightSettings = JpegCompressionSettings(
      maxDimensionPx: SyntheticImageFixtures.mediumWidth,
      quality: SyntheticImageFixtures.highQuality,
      maxBytes: SyntheticImageFixtures.tightMaxBytes
    )
    let artifact = try store.ingestPhoto(
      PhotoIngestRequest(
        mediaId: SyntheticImageFixtures.mediaId,
        rawData: rawData,
        source: .camera,
        compression: tightSettings,
        now: SyntheticImageFixtures.sampleNow,
        timeZoneIdentifier: SyntheticImageFixtures.warsawTimeZone
      )
    )
    #expect(rawData.count > SyntheticImageFixtures.tightMaxBytes)
    #expect(artifact.bytes <= SyntheticImageFixtures.tightMaxBytes)
    #expect(artifact.bytes < rawData.count)

    let impossibleSettings = JpegCompressionSettings(
      maxDimensionPx: SyntheticImageFixtures.mediumWidth,
      quality: SyntheticImageFixtures.highQuality,
      maxBytes: SyntheticImageFixtures.impossibleMaxBytes
    )
    #expect(throws: MediaStorageError.self) {
      try store.ingestPhoto(
        PhotoIngestRequest(
          mediaId: SyntheticImageFixtures.remoteMediaId,
          rawData: rawData,
          source: .camera,
          compression: impossibleSettings,
          now: SyntheticImageFixtures.sampleNow
        )
      )
    }
  }

  @Test("Marks missing-EXIF imports with capturedAtFromImport while keeping camera false")
  func missingExifImportFlagAndDeviceLocationPrecedence() throws {
    let tempDir = makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let store = LocalMediaStore(baseDirectory: tempDir)

    let noExifData = try SyntheticImageFixtures.makeSyntheticJpegData(
      width: SyntheticImageFixtures.mediumWidth,
      height: SyntheticImageFixtures.mediumHeight,
      includeExifAndGps: false
    )

    let importedArtifact = try store.ingestPhoto(
      PhotoIngestRequest(
        mediaId: SyntheticImageFixtures.mediaId,
        rawData: noExifData,
        source: .imported,
        now: SyntheticImageFixtures.sampleNow,
        timeZoneIdentifier: SyntheticImageFixtures.warsawTimeZone
      )
    )
    #expect(importedArtifact.capturedAtFromImport)
    #expect(importedArtifact.capturedAt == SyntheticImageFixtures.sampleNow)
    #expect(importedArtifact.capturedTz == SyntheticImageFixtures.warsawTimeZone)
    #expect(importedArtifact.location == nil)

    let deviceLocation = CaptureLocationMetadata(
      lat: SyntheticImageFixtures.deviceLat,
      lng: SyntheticImageFixtures.deviceLng,
      accuracyM: SyntheticImageFixtures.gpsAccuracyM,
      locationSource: .device
    )
    let cameraArtifact = try store.ingestPhoto(
      PhotoIngestRequest(
        mediaId: SyntheticImageFixtures.remoteMediaId,
        rawData: noExifData,
        source: .camera,
        deviceLocation: deviceLocation,
        now: SyntheticImageFixtures.sampleNow,
        timeZoneIdentifier: SyntheticImageFixtures.warsawTimeZone
      )
    )
    #expect(!cameraArtifact.capturedAtFromImport)
    #expect(cameraArtifact.location == deviceLocation)
  }

  private func makeTempDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString,
      isDirectory: true
    )
  }
}
