import Foundation

public enum AuthClientError: Error, Equatable, Sendable {
  case cancelled
  case invalidCredential(String)
  case invalidFirebaseUid
  case appleSignInUnavailable
  case keychainFailure(Int32)
  case encodingFailed
  case nonceGenerationFailed(Int32)
  case firebaseConfigurationMissing
  case firebaseExchangeFailed(Int, String)
  case firebaseRefreshFailed(Int, String)
}

public struct AuthSession: Codable, Equatable, Hashable, Sendable {
  public let firebaseUid: String
  public var displayName: String?
  public let bearerToken: String
  public let appleAuthorizationCode: String?
  public let refreshToken: String?
  public let expiresAt: Date?

  public init(
    firebaseUid: String,
    displayName: String? = nil,
    bearerToken: String,
    appleAuthorizationCode: String? = nil,
    refreshToken: String? = nil,
    expiresAt: Date? = nil
  ) {
    self.firebaseUid = firebaseUid
    self.displayName = displayName
    self.bearerToken = bearerToken
    self.appleAuthorizationCode = appleAuthorizationCode
    self.refreshToken = refreshToken
    self.expiresAt = expiresAt
  }

  public func needsRefresh(
    now: Date,
    leeway: TimeInterval = AuthClientConstants.firebaseRefreshLeewaySeconds
  ) -> Bool {
    guard refreshToken != nil, let expiresAt else {
      return false
    }
    return expiresAt.timeIntervalSince(now) <= leeway
  }
}

public struct AppleSignInCredential: Equatable, Hashable, Sendable {
  public let userIdentifier: String
  public let identityToken: String
  public let authorizationCode: String
  public let displayName: String?
  public let rawNonce: String?

  public init(
    userIdentifier: String,
    identityToken: String,
    authorizationCode: String,
    displayName: String? = nil,
    rawNonce: String? = nil
  ) {
    self.userIdentifier = userIdentifier
    self.identityToken = identityToken
    self.authorizationCode = authorizationCode
    self.displayName = displayName
    self.rawNonce = rawNonce
  }
}

public enum LocalDevTokenFormatter: Sendable {
  public static func formatToken(
    firebaseUid: String,
    displayName: String?
  ) throws -> String {
    let trimmedUid = firebaseUid.trimmingCharacters(in: .whitespacesAndNewlines)
    guard
      !trimmedUid.isEmpty,
      !trimmedUid.contains(AuthClientConstants.localDevSeparator)
    else {
      throw AuthClientError.invalidFirebaseUid
    }

    let trimmedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let trimmedName, !trimmedName.isEmpty else {
      return "\(AuthClientConstants.localDevTokenPrefix)\(trimmedUid)"
    }
    guard
      let encoded = trimmedName.addingPercentEncoding(
        withAllowedCharacters: AuthClientConstants.unreservedURLCharacters
      )
    else {
      throw AuthClientError.encodingFailed
    }
    return
      "\(AuthClientConstants.localDevTokenPrefix)\(trimmedUid)\(AuthClientConstants.localDevSeparator)\(encoded)"
  }
}
