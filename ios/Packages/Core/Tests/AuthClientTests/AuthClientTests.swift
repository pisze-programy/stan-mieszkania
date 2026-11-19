import AuthClient
import Dependencies
import Foundation
import Testing

@Suite("AuthClient Session and Local Dev Token Tests")
struct AuthClientTests {
  @Test("Formats local dev bearer tokens matching backend local-dev-token-verifier")
  func formatsLocalDevBearerTokens() throws {
    let withPolishName = try LocalDevTokenFormatter.formatToken(
      firebaseUid: "user-123",
      displayName: "Łukasz Żółć"
    )
    #expect(withPolishName == "dev:user-123:%C5%81ukasz%20%C5%BB%C3%B3%C5%82%C4%87")

    let withoutName = try LocalDevTokenFormatter.formatToken(
      firebaseUid: "  user-456  ",
      displayName: "   "
    )
    #expect(withoutName == "dev:user-456")

    #expect(throws: AuthClientError.invalidFirebaseUid) {
      try LocalDevTokenFormatter.formatToken(firebaseUid: "   ", displayName: "Anna")
    }
    #expect(throws: AuthClientError.invalidFirebaseUid) {
      try LocalDevTokenFormatter.formatToken(firebaseUid: "bad:uid", displayName: "Anna")
    }
  }

  @Test("Persists and clears sessions across local dev, Apple sign-in, and fresh auth code")
  func managesSessionLifecycleInStore() async throws {
    let store = InMemoryAuthSessionStore()
    let client = AuthClient.live(
      store: store,
      appleCredentialProvider: { _ in
        AppleSignInCredential(
          userIdentifier: "apple-uid-1",
          identityToken: "apple-jwt-token",
          authorizationCode: "fresh-apple-code",
          displayName: "Anna Nowak"
        )
      }
    )

    try await withDependencies {
      $0.authClient = client
    } operation: {
      @Dependency(\.authClient) var authClient

      #expect(try await authClient.loadStoredSession() == nil)

      let devSession = try await authClient.signInLocalDev("dev-user", "Jan Kowalski")
      #expect(devSession.bearerToken == "dev:dev-user:Jan%20Kowalski")
      #expect(try await authClient.loadStoredSession() == devSession)

      let appleSession = try await authClient.signInWithApple()
      #expect(appleSession.firebaseUid == "apple-uid-1")
      #expect(appleSession.bearerToken == "apple-jwt-token")
      #expect(appleSession.appleAuthorizationCode == "fresh-apple-code")
      #expect(try await authClient.loadStoredSession() == appleSession)

      let freshCode = try await authClient.requestFreshAppleAuthorizationCode()
      #expect(freshCode == "fresh-apple-code")

      try await authClient.clearSession()
      #expect(try await authClient.loadStoredSession() == nil)
    }
  }
}
