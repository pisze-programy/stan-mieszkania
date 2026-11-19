import Domain
import Foundation
import HTTPTypes
import OpenAPIRuntime

public struct APIRequestMiddleware: ClientMiddleware, Sendable {
  private let tokenProvider: @Sendable () async -> String?
  private let appVersion: String
  private let requestIdGenerator: @Sendable () -> String

  public init(
    tokenProvider: @escaping @Sendable () async -> String?,
    appVersion: String = APIClientConstants.defaultAppVersion,
    requestIdGenerator: @escaping @Sendable () -> String = UUIDv7.generateNow
  ) {
    self.tokenProvider = tokenProvider
    self.appVersion = appVersion
    self.requestIdGenerator = requestIdGenerator
  }

  public func intercept(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
  ) async throws -> (HTTPResponse, HTTPBody?) {
    var mutated = request

    if let token = await tokenProvider() {
      let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
      let authHeader = HTTPField.Name(APIClientConstants.authorizationHeaderName)
      if !trimmed.isEmpty, let authHeader {
        mutated.headerFields[authHeader] = "\(APIClientConstants.bearerPrefix)\(trimmed)"
      }
    }

    if let versionHeader = HTTPField.Name(APIClientConstants.appVersionHeaderName) {
      mutated.headerFields[versionHeader] = appVersion
    }

    let requestIdHeader = HTTPField.Name(APIClientConstants.requestIdHeaderName)
    if let requestIdHeader, mutated.headerFields[requestIdHeader] == nil {
      mutated.headerFields[requestIdHeader] = requestIdGenerator()
    }

    return try await next(mutated, body, baseURL)
  }
}
