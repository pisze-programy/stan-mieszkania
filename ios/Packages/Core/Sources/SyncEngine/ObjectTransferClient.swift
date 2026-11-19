import Dependencies
import DependenciesMacros
import Foundation

public typealias UploadProgressHandler = @Sendable (_ fractionCompleted: Double) -> Void

@DependencyClient
public struct ObjectTransferClient: Sendable {
  public var uploadJpeg:
    @Sendable (_ fileURL: URL, _ presignedURL: URL, _ onProgress: @escaping UploadProgressHandler)
      async throws -> Void
  public var downloadJpeg: @Sendable (_ presignedURL: URL) async throws -> Data

  public static func makeLiveSessionConfiguration() -> URLSessionConfiguration {
    let config = URLSessionConfiguration.default
    // Decision S2-7: Media uploads and downloads are permitted over cellular connections.
    config.allowsCellularAccess = true
    config.waitsForConnectivity = true
    return config
  }

  public static func makeBackgroundSessionConfiguration(
    identifier: String = SyncEngineConstants.backgroundSessionIdentifier
  ) -> URLSessionConfiguration {
    let config = URLSessionConfiguration.background(withIdentifier: identifier)
    config.allowsCellularAccess = true
    config.isDiscretionary = false
    config.sessionSendsLaunchEvents = true
    return config
  }

  public static func live(
    configuration: URLSessionConfiguration = Self.makeLiveSessionConfiguration()
  ) -> Self {
    let session = URLSession(configuration: configuration)
    return Self(
      uploadJpeg: { fileURL, presignedURL, onProgress in
        var request = URLRequest(url: presignedURL)
        request.httpMethod = SyncEngineConstants.putHTTPMethod
        request.setValue(
          SyncEngineConstants.jpegContentType,
          forHTTPHeaderField: SyncEngineConstants.contentTypeHeader
        )
        request.allowsCellularAccess = true

        let delegate = UploadProgressDelegate(onProgress: onProgress)
        let (_, response) = try await session.upload(
          for: request,
          fromFile: fileURL,
          delegate: delegate
        )
        try validateHTTPResponse(response)
      },
      downloadJpeg: { presignedURL in
        var request = URLRequest(url: presignedURL)
        request.httpMethod = SyncEngineConstants.getHTTPMethod
        request.allowsCellularAccess = true

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response)
        return data
      }
    )
  }

  private static func validateHTTPResponse(_ response: URLResponse) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
      throw SyncEngineError.invalidHTTPStatus(0)
    }
    let validRange =
      SyncEngineConstants.minSuccessStatusCode...SyncEngineConstants.maxSuccessStatusCode
    guard validRange.contains(httpResponse.statusCode) else {
      throw SyncEngineError.invalidHTTPStatus(httpResponse.statusCode)
    }
  }
}

private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, Sendable {
  private let onProgress: UploadProgressHandler

  init(onProgress: @escaping UploadProgressHandler) {
    self.onProgress = onProgress
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didSendBodyData bytesSent: Int64,
    totalBytesSent: Int64,
    totalBytesExpectedToSend: Int64
  ) {
    guard totalBytesExpectedToSend > 0 else {
      return
    }
    let raw = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
    let clamped = min(max(raw, SyncEngineConstants.minProgress), SyncEngineConstants.maxProgress)
    onProgress(clamped)
  }
}

extension ObjectTransferClient: DependencyKey {
  public static var liveValue: ObjectTransferClient {
    .live()
  }

  public static var testValue: ObjectTransferClient {
    ObjectTransferClient()
  }
}

extension DependencyValues {
  public var objectTransfer: ObjectTransferClient {
    get { self[ObjectTransferClient.self] }
    set { self[ObjectTransferClient.self] = newValue }
  }
}
