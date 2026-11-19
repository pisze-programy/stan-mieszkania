import Foundation

public enum SyncEngineConstants: Sendable {
  public static let jpegContentType: String = "image/jpeg"
  public static let contentTypeHeader: String = "Content-Type"
  public static let putHTTPMethod: String = "PUT"
  public static let getHTTPMethod: String = "GET"
  public static let backgroundSessionIdentifier: String = "pl.stanmieszkania.app.media-upload"
  public static let minSuccessStatusCode: Int = 200
  public static let maxSuccessStatusCode: Int = 299
  public static let baseBackoffSeconds: TimeInterval = 5
  public static let maxBackoffSeconds: TimeInterval = 300
  public static let maxBackoffExponent: Int = 6
  public static let backoffMultiplier: Double = 2
  public static let minProgress: Double = 0
  public static let maxProgress: Double = 1
  public static let changeFeedPageSize: Int = 50
  public static let outboxBatchLimit: Int = 100
  public static let transientErrorCode: String = "TRANSIENT_NETWORK_ERROR"
  public static let rankApartment: Int = 0
  public static let rankMediaUpload: Int = 1
  public static let rankEntryCreate: Int = 2
  public static let rankTombstone: Int = 3
  public static let rankUnknown: Int = 4
}
