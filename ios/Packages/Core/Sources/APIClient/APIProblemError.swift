import Domain
import Foundation
import OpenAPIRuntime

public struct APIProblemError: Error, Equatable, Sendable {
  public let status: Int
  public let code: ServerErrorCode
  public let title: String
  public let detail: String
  public let requestId: String?

  public var isQuotaExceeded: Bool {
    code == .known(.quotaExceeded)
  }

  public var isUpdateRequired: Bool {
    code == .known(.appUpdateRequired)
      || status == APIClientConstants.upgradeRequiredStatusCode
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
