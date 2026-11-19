import Domain
import Foundation
import OpenAPIRuntime

public struct APIProblemError: ServerErrorCodeConvertible, Equatable, Sendable {
  public let status: Int
  public let code: ServerErrorCode
  public let title: String
  public let detail: String
  public let requestId: String?

  public var serverErrorCode: ServerErrorCode {
    code
  }

  public var isQuotaExceeded: Bool {
    code == .known(.quotaExceeded)
  }

  public var isUpdateRequired: Bool {
    code == .known(.appUpdateRequired)
      || status == APIClientConstants.upgradeRequiredStatusCode
  }

  public var isNetworkUnavailable: Bool {
    code == .unknown(APIClientConstants.networkUnavailableErrorCode)
  }

  public init(
    status: Int,
    code: ServerErrorCode,
    title: String,
    detail: String,
    requestId: String? = nil
  ) {
    self.status = status
    self.code = code
    self.title = title
    self.detail = detail
    self.requestId = requestId
  }

  public static func networkUnavailable(detail: String) -> Self {
    Self(
      status: 0,
      code: .unknown(APIClientConstants.networkUnavailableErrorCode),
      title: APIClientConstants.networkUnavailableTitle,
      detail: detail
    )
  }
}

enum ProblemResponseMapper: Sendable {
  private struct WireProblemDetails: Decodable {
    let status: Int
    let code: String
    let title: String
    let detail: String
    let requestId: String?
  }

  static func map(_ problem: Components.Schemas.ProblemDetails) -> APIProblemError {
    APIProblemError(
      status: problem.status,
      code: ServerErrorCode(rawValue: problem.code),
      title: problem.title,
      detail: problem.detail,
      requestId: problem.requestId
    )
  }

  static func mapUndocumented(
    statusCode: Int,
    payload: UndocumentedPayload
  ) async -> APIProblemError {
    if let body = payload.body {
      let data = try? await Data(collecting: body, upTo: APIClientConstants.maxProblemBodyBytes)
      if let data, let decoded = try? JSONDecoder().decode(WireProblemDetails.self, from: data) {
        return APIProblemError(
          status: decoded.status,
          code: ServerErrorCode(rawValue: decoded.code),
          title: decoded.title,
          detail: decoded.detail,
          requestId: decoded.requestId
        )
      }
    }

    return APIProblemError(
      status: statusCode,
      code: .unknown("\(APIClientConstants.httpStatusErrorCodePrefix)\(statusCode)"),
      title: HTTPURLResponse.localizedString(forStatusCode: statusCode),
      detail: APIClientConstants.unexpectedResponseDetail
    )
  }
}

enum TransportErrorMapper: Sendable {
  private static let maxUnderlyingDepth: Int = 4

  static func run<T: Sendable>(_ operation: () async throws -> T) async throws -> T {
    do {
      return try await operation()
    } catch let problem as APIProblemError {
      throw problem
    } catch let clientError as OpenAPIRuntime.ClientError {
      if let problem = clientError.underlyingError as? APIProblemError {
        throw problem
      }
      if isNetworkError(clientError.underlyingError) {
        throw APIProblemError.networkUnavailable(
          detail: clientError.underlyingError.localizedDescription
        )
      }
      throw clientError
    } catch {
      if isNetworkError(error) {
        throw APIProblemError.networkUnavailable(detail: error.localizedDescription)
      }
      throw error
    }
  }

  private static func isNetworkError(_ error: any Error) -> Bool {
    var current: (any Error)? = error
    var depth = 0
    while let candidate = current, depth < maxUnderlyingDepth {
      if let urlError = candidate as? URLError, isConnectivityCode(urlError.code) {
        return true
      }
      let nsError = candidate as NSError
      let urlCode = URLError.Code(rawValue: nsError.code)
      if nsError.domain == NSURLErrorDomain, isConnectivityCode(urlCode) {
        return true
      }
      current = nsError.userInfo[NSUnderlyingErrorKey] as? any Error
      depth += 1
    }
    return false
  }

  private static func isConnectivityCode(_ code: URLError.Code) -> Bool {
    switch code {
    case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
      .networkConnectionLost, .timedOut, .dataNotAllowed, .internationalRoamingOff,
      .callIsActive, .secureConnectionFailed, .cannotLoadFromNetwork:
      return true
    default:
      return false
    }
  }
}
