import Foundation

public enum APIClientConstants: Sendable {
  public static let authorizationHeaderName: String = "Authorization"
  public static let bearerPrefix: String = "Bearer "
  public static let appVersionHeaderName: String = "X-App-Version"
  public static let requestIdHeaderName: String = "X-Request-Id"
  public static let defaultBaseURLString: String = "https://api.stanmieszkania.pl"
  public static let defaultAppVersion: String = "1.0.0"
  public static let maxProblemBodyBytes: Int = 65_536
  public static let upgradeRequiredStatusCode: Int = 426
  public static let httpStatusErrorCodePrefix: String = "HTTP_"
  public static let networkUnavailableErrorCode: String = "NETWORK_UNAVAILABLE"
  public static let networkUnavailableTitle: String = "Network unavailable"
  public static let unexpectedResponseDetail: String = "Unexpected response from server"
  public static let invalidResponseURLDetail: String = "Invalid URL returned by server"
}
