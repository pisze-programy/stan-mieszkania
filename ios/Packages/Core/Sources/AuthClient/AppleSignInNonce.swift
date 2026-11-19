import CryptoKit
import Foundation
import Security

public struct AppleSignInNonce: Equatable, Hashable, Sendable {
  private static let charset: [Character] = Array(
    "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
  )

  public let rawValue: String
  public let sha256Hex: String

  public init(rawValue: String) {
    self.rawValue = rawValue
    self.sha256Hex = Self.sha256Hex(of: rawValue)
  }

  public static func generate(
    length: Int = AuthClientConstants.appleNonceLength
  ) throws -> Self {
    precondition(length > 0)
    var randomBytes = [UInt8](repeating: 0, count: length)
    let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    guard status == errSecSuccess else {
      throw AuthClientError.nonceGenerationFailed(status)
    }
    let rawNonce = String(
      randomBytes.map { byte in
        charset[Int(byte) % charset.count]
      }
    )
    return Self(rawValue: rawNonce)
  }

  public static func sha256Hex(of rawNonce: String) -> String {
    let digest = SHA256.hash(data: Data(rawNonce.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}
