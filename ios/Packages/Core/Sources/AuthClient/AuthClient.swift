import AuthenticationServices
import Dependencies
import DependenciesMacros
import Foundation

public typealias AppleCredentialProvider =
  @Sendable (_ scopes: [ASAuthorization.Scope]) async throws -> AppleSignInCredential

public typealias AppleSessionExchanger =
  @Sendable (_ credential: AppleSignInCredential) async throws -> AuthSession

public typealias AuthSessionRefresher =
  @Sendable (_ session: AuthSession) async throws -> AuthSession

@DependencyClient
public struct AuthClient: Sendable {
  public var loadStoredSession: @Sendable () async throws -> AuthSession?
  public var validBearerToken: @Sendable () async throws -> String?
  public var signInWithApple: @Sendable () async throws -> AuthSession
  public var signInLocalDev:
    @Sendable (_ firebaseUid: String, _ displayName: String?) async throws -> AuthSession
  public var requestFreshAppleAuthorizationCode: @Sendable () async throws -> String
  public var clearSession: @Sendable () async throws -> Void

  public static func live(
    store: any AuthSessionStore = KeychainAuthSessionStore(),
    appleCredentialProvider: @escaping AppleCredentialProvider = Self
      .defaultAppleCredentialProvider,
    sessionExchanger: @escaping AppleSessionExchanger = Self.defaultSessionExchanger,
    sessionRefresher: AuthSessionRefresher? = nil,
    now: @escaping @Sendable () -> Date = Date.init
  ) -> Self {
    let coordinator = SessionRefreshCoordinator(
      store: store,
      refresher: sessionRefresher,
      now: now
    )
    return Self(
      loadStoredSession: {
        try store.load()
      },
      validBearerToken: {
        try await coordinator.validBearerToken()
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
        await coordinator.cancelInFlightRefresh()
        try store.clear()
      }
    )
  }

  public static func liveFirebase(
    store: any AuthSessionStore = KeychainAuthSessionStore(),
    firebaseClient: FirebaseIdentityToolkitClient,
    appleCredentialProvider: @escaping AppleCredentialProvider = Self
      .defaultAppleCredentialProvider,
    now: @escaping @Sendable () -> Date = Date.init
  ) -> Self {
    .live(
      store: store,
      appleCredentialProvider: appleCredentialProvider,
      sessionExchanger: { credential in
        try await firebaseClient.exchangeAppleCredential(credential)
      },
      sessionRefresher: { session in
        try await firebaseClient.refreshSession(session)
      },
      now: now
    )
  }

  public static func defaultAppleCredentialProvider(
    scopes: [ASAuthorization.Scope]
  ) async throws -> AppleSignInCredential {
    let nonce = try AppleSignInNonce.generate()
    return try await MainActor.run {
      AppleSignInBridge()
    }.requestCredential(scopes: scopes, nonce: nonce)
  }

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

private actor SessionRefreshCoordinator {
  private let store: any AuthSessionStore
  private let refresher: AuthSessionRefresher?
  private let now: @Sendable () -> Date
  private var inFlightRefresh: Task<AuthSession, any Error>?

  init(
    store: any AuthSessionStore,
    refresher: AuthSessionRefresher?,
    now: @escaping @Sendable () -> Date
  ) {
    self.store = store
    self.refresher = refresher
    self.now = now
  }

  func validBearerToken() async throws -> String? {
    guard let session = try store.load() else {
      return nil
    }
    if session.bearerToken.hasPrefix(AuthClientConstants.localDevTokenPrefix) {
      return session.bearerToken
    }
    guard let refresher, session.needsRefresh(now: now()) else {
      return session.bearerToken
    }
    if let existingTask = inFlightRefresh {
      return try await existingTask.value.bearerToken
    }
    let task = Task<AuthSession, any Error> {
      let refreshed = try await refresher(session)
      try store.save(refreshed)
      return refreshed
    }
    inFlightRefresh = task
    defer { inFlightRefresh = nil }
    return try await task.value.bearerToken
  }

  func cancelInFlightRefresh() {
    inFlightRefresh?.cancel()
    inFlightRefresh = nil
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
