import CryptoKit
import Foundation

public enum SHA256Hasher: Sendable {
  public static func hexDigest(of data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: MediaStorageConstants.hexByteFormat, $0) }.joined()
  }

  public static func matches(_ data: Data, expectedHex: String) -> Bool {
    hexDigest(of: data) == expectedHex.lowercased()
  }
}
