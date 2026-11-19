import CoreGraphics
import Dependencies
import DependenciesMacros
import Domain
import Foundation

@DependencyClient
public struct MediaStorageClient: Sendable {
  public var ingestPhoto: @Sendable (_ request: PhotoIngestRequest) throws -> ProcessedPhotoArtifact
  public var storeRemotePhoto:
    @Sendable (_ jpegData: Data, _ expectedSha256: String, _ mediaId: String) throws -> String
  public var loadDownsampledThumbnail:
    @Sendable (_ mediaId: String, _ maxPixelSize: Int) throws -> CGImage
  public var loadPhotoData: @Sendable (_ mediaId: String) throws -> Data
  public var fileExists: @Sendable (_ mediaId: String) -> Bool = { _ in false }
  public var deleteLocalFile: @Sendable (_ mediaId: String) throws -> Void

  public static func live(baseDirectory: URL) -> Self {
    let store = LocalMediaStore(baseDirectory: baseDirectory)
    return Self(
      ingestPhoto: { request in
        try store.ingestPhoto(request)
      },
      storeRemotePhoto: { jpegData, expectedSha256, mediaId in
        try store.storeRemotePhoto(
          jpegData: jpegData,
          expectedSha256: expectedSha256,
          mediaId: mediaId
        )
      },
      loadDownsampledThumbnail: { mediaId, maxPixelSize in
        try store.loadDownsampledThumbnail(mediaId: mediaId, maxPixelSize: maxPixelSize)
      },
      loadPhotoData: { mediaId in
        try store.loadPhotoData(mediaId: mediaId)
      },
      fileExists: { mediaId in
        store.fileExists(mediaId: mediaId)
      },
      deleteLocalFile: { mediaId in
        try store.deleteLocalFile(mediaId: mediaId)
      }
    )
  }
}

extension MediaStorageClient: DependencyKey {
  public static var liveValue: MediaStorageClient {
    let baseDirectory: URL
    if let appSupport = try? FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    ) {
      baseDirectory = appSupport.appendingPathComponent(
        MediaStorageConstants.defaultCacheFolderName,
        isDirectory: true
      )
    } else {
      baseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
        MediaStorageConstants.defaultCacheFolderName,
        isDirectory: true
      )
    }
    return .live(baseDirectory: baseDirectory)
  }

  public static var testValue: MediaStorageClient {
    MediaStorageClient()
  }
}

extension DependencyValues {
  public var mediaStorage: MediaStorageClient {
    get { self[MediaStorageClient.self] }
    set { self[MediaStorageClient.self] = newValue }
  }
}
