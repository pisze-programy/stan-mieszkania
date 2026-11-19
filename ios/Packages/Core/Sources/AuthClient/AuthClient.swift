import AuthenticationServices
import Dependencies
import DependenciesMacros
import Foundation

public typealias AppleCredentialProvider =
  @Sendable (_ scopes: [ASAuthorization.Scope]) async throws -> AppleSignInCredential

public typealias AppleSessionExchanger =
  @Sendable (_ credential: AppleSignInCredential) async throws -> AuthSession

@DependencyClient
public struct AuthClient: Sendable {
  public var loadStoredSession: @Sendable () async throws -> AuthSession?
  public var signInWithApple: @Sendable () async throws -> AuthSession
  public var signInLocalDev:
    @Sendable (_ firebaseUid: String, _ displayName: String?) async throws -> AuthSession
  public var requestFreshAppleAuthorizationCode: @Sendable () async throws -> String
  public var clearSession: @Sendable () async throws -> Void

  public static func live(
    store: any AuthSessionStore = KeychainAuthSessionStore(),
    appleCredentialProvider: @escaping AppleCredentialProvider = Self
      .defaultAppleCredentialProvider,
    sessionExchanger: @escaping AppleSessionExchanger = Self.defaultSessionExchanger
  ) -> Self {
    Self(
      loadStoredSession: {
        try store.load()
      },
      signInWithApple: {
        let credential = try await appleCredentialProvider([.fullName])
        let session = try await sessionExchanger(credential)
        try store.save(session)
        return session
      },
      signInLocalDev: { firebaseUid, displayName in
        let token = try LocalDevTokenFormatter.formatToken(
          firebaseUid: firebaseUid,
          displayName: displayName
        )
        let trimmedUid = firebaseUid.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = trimmedName?.isEmpty == false ? trimmedName : nil
        let session = AuthSession(
          firebaseUid: trimmedUid,
          displayName: normalizedName,
          bearerToken: token
        )
        try store.save(session)
        return session
      },
      requestFreshAppleAuthorizationCode: {
        // Decision Q12: Fresh Apple authorization code is required before account deletion revoke.
        let credential = try await appleCredentialProvider([])
        return credential.authorizationCode
      },
      clearSession: {
        try store.clear()
      }
    )
  }

  public static func defaultAppleCredentialProvider(
    scopes: [ASAuthorization.Scope]
  ) async throws -> AppleSignInCredential {
    try await MainActor.run {
      AppleSignInBridge()
    }.requestCredential(scopes: scopes)
  }

  // Decision Q12: Default exchanger maps Apple credential until Task 8.2 wires FirebaseAuth exchange.
  public static func defaultSessionExchanger(
    credential: AppleSignInCredential
  ) async throws -> AuthSession {
    AuthSession(
      firebaseUid: credential.userIdentifier,
      displayName: credential.displayName,
      bearerToken: credential.identityToken,
      appleAuthorizationCode: credential.authorizationCode
    )
  }
}

extension AuthClient: DependencyKey {
  public static var liveValue: AuthClient {
    .live()
  }

  public static var testValue: AuthClient {
    AuthClient()
  }
}

extension DependencyValues {
  public var authClient: AuthClient {
    get { self[AuthClient.self] }
    set { self[AuthClient.self] = newValue }
  }
}
