import Foundation

public struct FirebaseIdentityToolkitClient: Sendable {
  private let apiKeyProvider: @Sendable () -> String?
  private let transport: AuthHTTPTransport
  private let now: @Sendable () -> Date

  public init(
    apiKeyProvider: @escaping @Sendable () -> String?,
    transport: @escaping AuthHTTPTransport = Self.defaultTransport,
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.apiKeyProvider = apiKeyProvider
    self.transport = transport
    self.now = now
  }

  // Decision Q12: Exchange Apple identity token + rawNonce for Firebase ID/refresh tokens.
  public func exchangeAppleCredential(
    _ credential: AppleSignInCredential
  ) async throws -> AuthSession {
    let apiKey = try requireAPIKey()
    let request = try makeSignInWithIdpRequest(credential: credential, apiKey: apiKey)
    let (data, response) = try await transport(request)
    try FirebaseRequestHelpers.validateStatus(response, data: data) {
      AuthClientError.firebaseExchangeFailed($0, $1)
    }

    let decoded = try FirebaseRequestHelpers.decodeResponse(SignInWithIdpResponse.self, from: data)
    let candidateName = FirebaseRequestHelpers.normalizedName(credential.displayName)
    let firebaseName =
      FirebaseRequestHelpers.normalizedName(decoded.displayName)
      ?? FirebaseRequestHelpers.normalizedName(decoded.fullName)
    if let candidateName, firebaseName == nil {
      try? await updateFirebaseDisplayName(
        idToken: decoded.idToken,
        displayName: candidateName,
        apiKey: apiKey
      )
    }

    let lifetime = TimeInterval(decoded.expiresIn) ?? AuthClientConstants.defaultTokenExpirySeconds
    return AuthSession(
      firebaseUid: decoded.localId,
      displayName: firebaseName ?? candidateName,
      bearerToken: decoded.idToken,
      appleAuthorizationCode: credential.authorizationCode,
      refreshToken: decoded.refreshToken,
      expiresAt: now().addingTimeInterval(lifetime)
    )
  }

  // Decision Q12: Silently refresh expiring Firebase ID tokens via Secure Token API.
  public func refreshSession(_ session: AuthSession) async throws -> AuthSession {
    guard let refreshToken = session.refreshToken, !refreshToken.isEmpty else {
      return session
    }
    let apiKey = try requireAPIKey()
    let request = try makeRefreshTokenRequest(refreshToken: refreshToken, apiKey: apiKey)
    let (data, response) = try await transport(request)
    try FirebaseRequestHelpers.validateStatus(response, data: data) {
      AuthClientError.firebaseRefreshFailed($0, $1)
    }

    let decoded = try FirebaseRequestHelpers.decodeResponse(
      SecureTokenRefreshResponse.self,
      from: data
    )
    let lifetime = TimeInterval(decoded.expiresIn) ?? AuthClientConstants.defaultTokenExpirySeconds
    return AuthSession(
      firebaseUid: decoded.userId.isEmpty ? session.firebaseUid : decoded.userId,
      displayName: session.displayName,
      bearerToken: decoded.idToken,
      appleAuthorizationCode: session.appleAuthorizationCode,
      refreshToken: decoded.refreshToken,
      expiresAt: now().addingTimeInterval(lifetime)
    )
  }

  public static func defaultTransport(
    _ request: URLRequest
  ) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw AuthClientError.invalidCredential("Non-HTTP response from Firebase")
    }
    return (data, httpResponse)
  }

  private func requireAPIKey() throws -> String {
    guard let key = FirebaseAuthConfiguration.normalizeKey(apiKeyProvider()) else {
      throw AuthClientError.firebaseConfigurationMissing
    }
    return key
  }

  private func makeSignInWithIdpRequest(
    credential: AppleSignInCredential,
    apiKey: String
  ) throws -> URLRequest {
    let url = try FirebaseRequestHelpers.buildURL(
      base: AuthClientConstants.firebaseIdentityToolkitBaseURL,
      path: "/accounts:signInWithIdp",
      apiKey: apiKey
    )
    var pairs = [
      ("id_token", credential.identityToken),
      ("providerId", AuthClientConstants.appleProviderId),
    ]
    if let rawNonce = credential.rawNonce, !rawNonce.isEmpty {
      pairs.append(("nonce", rawNonce))
    }
    let payload = SignInWithIdpRequest(
      postBody: try FirebaseRequestHelpers.formEncode(pairs),
      requestUri: AuthClientConstants.defaultRequestUri,
      returnIdpCredential: true,
      returnSecureToken: true
    )
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(payload)
    return request
  }

  private func updateFirebaseDisplayName(
    idToken: String,
    displayName: String,
    apiKey: String
  ) async throws {
    let url = try FirebaseRequestHelpers.buildURL(
      base: AuthClientConstants.firebaseIdentityToolkitBaseURL,
      path: "/accounts:update",
      apiKey: apiKey
    )
    let payload = UpdateAccountRequest(
      idToken: idToken,
      displayName: displayName,
      returnSecureToken: false
    )
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(payload)
    _ = try await transport(request)
  }

  private func makeRefreshTokenRequest(
    refreshToken: String,
    apiKey: String
  ) throws -> URLRequest {
    let url = try FirebaseRequestHelpers.buildURL(
      base: AuthClientConstants.firebaseSecureTokenBaseURL,
      path: "/token",
      apiKey: apiKey
    )
    let body = try FirebaseRequestHelpers.formEncode([
      ("grant_type", "refresh_token"),
      ("refresh_token", refreshToken),
    ])
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = Data(body.utf8)
    return request
  }
}
