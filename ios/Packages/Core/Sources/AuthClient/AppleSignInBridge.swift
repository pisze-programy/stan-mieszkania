import AuthenticationServices
import Foundation

@MainActor
public final class AppleSignInBridge: NSObject, ASAuthorizationControllerDelegate {
  private var continuation: CheckedContinuation<AppleSignInCredential, any Error>?
  private var activeController: ASAuthorizationController?
  private var activeRawNonce: String?

  public override init() {
    super.init()
  }

  public func requestCredential(
    scopes: [ASAuthorization.Scope] = [.fullName],
    nonce: AppleSignInNonce? = nil
  ) async throws -> AppleSignInCredential {
    try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      self.activeRawNonce = nonce?.rawValue
      let provider = ASAuthorizationAppleIDProvider()
      let request = provider.createRequest()
      request.requestedScopes = scopes
      request.nonce = nonce?.sha256Hex

      let controller = ASAuthorizationController(authorizationRequests: [request])
      controller.delegate = self
      self.activeController = controller
      controller.performRequests()
    }
  }

  public nonisolated func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    Task { @MainActor in
      let rawNonce = self.activeRawNonce
      defer {
        self.activeController = nil
        self.activeRawNonce = nil
      }
      guard let resume = self.continuation else {
        return
      }
      self.continuation = nil

      guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
        resume.resume(throwing: AuthClientError.invalidCredential("Unexpected credential type"))
        return
      }
      guard
        let tokenData = credential.identityToken,
        let identityToken = String(data: tokenData, encoding: .utf8),
        let codeData = credential.authorizationCode,
        let authorizationCode = String(data: codeData, encoding: .utf8)
      else {
        resume.resume(throwing: AuthClientError.invalidCredential("Missing Apple token or code"))
        return
      }

      let displayName = Self.formatFullName(credential.fullName)
      resume.resume(
        returning: AppleSignInCredential(
          userIdentifier: credential.user,
          identityToken: identityToken,
          authorizationCode: authorizationCode,
          displayName: displayName,
          rawNonce: rawNonce
        )
      )
    }
  }

  public nonisolated func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithError error: any Error
  ) {
    Task { @MainActor in
      defer {
        self.activeController = nil
        self.activeRawNonce = nil
      }
      guard let resume = self.continuation else {
        return
      }
      self.continuation = nil

      let nsError = error as NSError
      let isCancelled =
        nsError.domain == ASAuthorizationError.errorDomain
        && nsError.code == ASAuthorizationError.canceled.rawValue
      if isCancelled {
        resume.resume(throwing: AuthClientError.cancelled)
        return
      }
      resume.resume(throwing: AuthClientError.invalidCredential(error.localizedDescription))
    }
  }

  private static func formatFullName(_ components: PersonNameComponents?) -> String? {
    guard let components else {
      return nil
    }
    let formatter = PersonNameComponentsFormatter()
    let formatted = formatter.string(from: components).trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    return formatted.isEmpty ? nil : formatted
  }
}
