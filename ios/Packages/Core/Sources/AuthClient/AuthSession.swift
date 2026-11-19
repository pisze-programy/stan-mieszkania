import Foundation

public enum AuthClientError: Error, Equatable, Sendable {
  case cancelled
  case invalidCredential(String)
  case invalidFirebaseUid
  case appleSignInUnavailable
  case keychainFailure(Int32)
  case encodingFailed
}

public struct AuthSession: Codable, Equatable, Hashable, Sendable {
  public let firebaseUid: String
  public var displayName: String?
  public let bearerToken: String
  public let appleAuthorizationCode: String?

  public init(
    firebaseUid: String,
    displayName: String? = nil,
    bearerToken: String,
    appleAuthorizationCode: String? = nil
  ) {
    self.firebaseUid = firebaseUid
    self.displayName = displayName
    self.bearerToken = bearerToken
    self.appleAuthorizationCode = appleAuthorizationCode
  }
}

public struct AppleSignInCredential: Equatable, Hashable, Sendable {
  public let userIdentifier: String
  public let identityToken: String
  public let authorizationCode: String
  public let displayName: String?

  public init(
    userIdentifier: String,
    identityToken: String,
    authorizationCode: String,
    displayName: String? = nil
  ) {
    self.userIdentifier = userIdentifier
    self.identityToken = identityToken
    self.authorizationCode = authorizationCode
    self.displayName = displayName
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
