import AuthClient
import Dependencies
import Foundation
import Testing

@Suite("Firebase Identity Toolkit and Apple Nonce Tests")
struct FirebaseIdentityToolkitTests {
  private enum Fixtures {
    static let apiKey = "AIzaSyTestKey12345"
    static let baseTimestamp: TimeInterval = 1_700_000_000
    static let baseDate = Date(timeIntervalSince1970: baseTimestamp)
    static let nearExpiryOffsetSeconds: TimeInterval = 3_400
    static let expectedLifetimeSeconds: TimeInterval = 3_600
    static let expectedExchangeRequestCount = 2
    static let httpStatusOK = 200
    static let expectedSha256HexLength = 64
    static let knownInput = "abc"
    static let knownSha256 =
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    static let credential = AppleSignInCredential(
      userIdentifier: "apple-user-1",
      identityToken: "apple.id.jwt",
      authorizationCode: "apple-auth-code-1",
      displayName: "Anna Nowak",
      rawNonce: "raw-nonce-xyz"
    )
    static let signInResponseJSON = """
      {"localId":"fb-uid-1","idToken":"fb-id-token-1","refreshToken":"fb-refresh-1","expiresIn":"3600"}
      """
    static let refreshResponseJSON = """
      {"id_token":"fb-id-token-2","refresh_token":"fb-refresh-2","expires_in":"3600","user_id":"fb-uid-1"}
      """
  }

  private actor RequestRecorder {
    var requests: [URLRequest] = []

    func append(_ request: URLRequest) {
      requests.append(request)
    }
  }

  @Test("Generates random AppleSignInNonce with deterministic lowercase SHA-256 hex")
  func generatesNonceAndDeterministicSha256() throws {
    let known = AppleSignInNonce(rawValue: Fixtures.knownInput)
    #expect(known.sha256Hex == Fixtures.knownSha256)
    #expect(AppleSignInNonce.sha256Hex(of: Fixtures.knownInput) == Fixtures.knownSha256)

    let first = try AppleSignInNonce.generate()
    let second = try AppleSignInNonce.generate()
    let allowedSet = Set(AppleSignInNonce.charset)
    #expect(allowedSet.count == AppleSignInNonce.charset.count)
    #expect(allowedSet.contains("W"))
    #expect((Int(UInt8.max) + 1).isMultiple(of: AppleSignInNonce.charset.count))
    #expect(first.rawValue.allSatisfy { allowedSet.contains($0) })
    #expect(first.rawValue.count == AuthClientConstants.appleNonceLength)
    #expect(first.sha256Hex.count == Fixtures.expectedSha256HexLength)
    #expect(first.rawValue != second.rawValue)
    #expect(first.sha256Hex == AppleSignInNonce.sha256Hex(of: first.rawValue))
  }

  @Test("Exchanges Apple credential with nonce via signInWithIdp and sets display name")
  func exchangesAppleCredentialViaSignInWithIdp() async throws {
    let recorder = RequestRecorder()
    let client = FirebaseIdentityToolkitClient(
      apiKeyProvider: { Fixtures.apiKey },
      transport: { request in
        await recorder.append(request)
        let url = request.url?.absoluteString ?? ""
        let body = url.contains("accounts:update") ? "{}" : Fixtures.signInResponseJSON
        return (Data(body.utf8), Self.makeHTTPResponse(url: request.url))
      },
      now: { Fixtures.baseDate }
    )

    let session = try await client.exchangeAppleCredential(Fixtures.credential)
    let captured = await recorder.requests
    #expect(captured.count == Fixtures.expectedExchangeRequestCount)
    let firstURL = captured[0].url?.absoluteString ?? ""
    #expect(firstURL.contains("accounts:signInWithIdp?key=\(Fixtures.apiKey)"))
    let firstBody = String(data: captured[0].httpBody ?? Data(), encoding: .utf8) ?? ""
    #expect(firstBody.contains("providerId=apple.com"))
    #expect(firstBody.contains("id_token=apple.id.jwt"))
    #expect(firstBody.contains("nonce=raw-nonce-xyz"))
    let secondURL = captured[1].url?.absoluteString ?? ""
    #expect(secondURL.contains("accounts:update?key=\(Fixtures.apiKey)"))

    #expect(session.firebaseUid == "fb-uid-1")
    #expect(session.displayName == "Anna Nowak")
    #expect(session.bearerToken == "fb-id-token-1")
    #expect(session.refreshToken == "fb-refresh-1")
    #expect(session.appleAuthorizationCode == "apple-auth-code-1")
    let expectedExpiry = Fixtures.baseDate.addingTimeInterval(Fixtures.expectedLifetimeSeconds)
    #expect(session.expiresAt == expectedExpiry)
  }

  @Test("Silently refreshes near-expiry Firebase ID token via securetoken and persists session")
  func silentlyRefreshesExpiringFirebaseToken() async throws {
    let store = InMemoryAuthSessionStore()
    let currentTime = LockIsolated(Fixtures.baseDate)
    let refreshCalls = LockIsolated(0)
    let firebaseClient = FirebaseIdentityToolkitClient(
      apiKeyProvider: { Fixtures.apiKey },
      transport: { request in
        let url = request.url?.absoluteString ?? ""
        if url.contains("securetoken.googleapis.com") {
          refreshCalls.withValue { $0 += 1 }
          let form = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
          #expect(form.contains("grant_type=refresh_token"))
          #expect(form.contains("refresh_token=fb-refresh-1"))
          return (
            Data(Fixtures.refreshResponseJSON.utf8),
            Self.makeHTTPResponse(url: request.url)
          )
        }
        return (Data(Fixtures.signInResponseJSON.utf8), Self.makeHTTPResponse(url: request.url))
      },
      now: { currentTime.value }
    )

    let authClient = AuthClient.liveFirebase(
      store: store,
      firebaseClient: firebaseClient,
      appleCredentialProvider: { _ in Fixtures.credential },
      now: { currentTime.value }
    )

    _ = try await authClient.signInWithApple()
    #expect(try await authClient.validBearerToken() == "fb-id-token-1")
    #expect(refreshCalls.value == 0)

    currentTime.setValue(Fixtures.baseDate.addingTimeInterval(Fixtures.nearExpiryOffsetSeconds))
    let refreshedToken = try await authClient.validBearerToken()
    #expect(refreshedToken == "fb-id-token-2")
    #expect(refreshCalls.value == 1)

    let stored = try store.load()
    #expect(stored?.bearerToken == "fb-id-token-2")
    #expect(stored?.refreshToken == "fb-refresh-2")
    #expect(stored?.appleAuthorizationCode == "apple-auth-code-1")
  }

  @Test("Fails closed with firebaseConfigurationMissing when API key is absent or placeholder")
  func failsClosedWhenFirebaseAPIKeyMissing() async throws {
    let invalidKeys: [String?] = [
      nil,
      "",
      "   ",
      "REPLACE_WITH_FIREBASE_WEB_API_KEY",
      "$(FIREBASE_WEB_API_KEY)",
    ]
    for candidate in invalidKeys {
      let client = FirebaseIdentityToolkitClient(
        apiKeyProvider: { candidate },
        transport: { _ in
          Issue.record("Transport must not run")
          throw AuthClientError.encodingFailed
        }
      )
      await #expect(throws: AuthClientError.firebaseConfigurationMissing) {
        try await client.exchangeAppleCredential(Fixtures.credential)
      }
    }
  }

  private static func makeHTTPResponse(url: URL?) -> HTTPURLResponse {
    guard
      let response = HTTPURLResponse(
        url: url ?? URL(fileURLWithPath: "/"),
        statusCode: Fixtures.httpStatusOK,
        httpVersion: nil,
        headerFields: nil
      )
    else {
      fatalError("Failed to construct HTTPURLResponse")
    }
    return response
  }
}
