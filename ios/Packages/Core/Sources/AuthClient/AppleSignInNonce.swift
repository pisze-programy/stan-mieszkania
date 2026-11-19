import CryptoKit
import Foundation
import Security

public struct AppleSignInNonce: Equatable, Hashable, Sendable {
  public static let charset: [Character] = Array(
    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
  )
  private static let byteSpaceSize: Int = Int(UInt8.max) + 1
  private static let unbiasedByteLimit: Int = byteSpaceSize - (byteSpaceSize % charset.count)

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
    var characters: [Character] = []
    characters.reserveCapacity(length)

    while characters.count < length {
      var batch = [UInt8](repeating: 0, count: length - characters.count)
      let status = SecRandomCopyBytes(kSecRandomDefault, batch.count, &batch)
      guard status == errSecSuccess else {
        throw AuthClientError.nonceGenerationFailed(status)
      }
      for byte in batch where Int(byte) < unbiasedByteLimit {
        characters.append(charset[Int(byte) % charset.count])
        if characters.count == length {
          break
        }
      }
    }

    return Self(rawValue: String(characters))
  }

  public static func sha256Hex(of rawNonce: String) -> String {
    let digest = SHA256.hash(data: Data(rawNonce.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}
