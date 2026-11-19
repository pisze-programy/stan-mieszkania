import Foundation
import Security
import Synchronization

public protocol AuthSessionStore: Sendable {
  func load() throws -> AuthSession?
  func save(_ session: AuthSession) throws
  func clear() throws
}

public final class InMemoryAuthSessionStore: AuthSessionStore, Sendable {
  private let storage: Mutex<AuthSession?>

  public init(initialSession: AuthSession? = nil) {
    self.storage = Mutex(initialSession)
  }

  public func load() throws -> AuthSession? {
    storage.withLock { $0 }
  }

  public func save(_ session: AuthSession) throws {
    storage.withLock { $0 = session }
  }

  public func clear() throws {
    storage.withLock { $0 = nil }
  }
}

public struct KeychainAuthSessionStore: AuthSessionStore, Sendable {
  private let service: String
  private let account: String

  public init(
    service: String = AuthClientConstants.keychainService,
    account: String = AuthClientConstants.keychainAccount
  ) {
    self.service = service
    self.account = account
  }

  public func load() throws -> AuthSession? {
    var query = baseQuery()
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess else {
      throw AuthClientError.keychainFailure(status)
    }
    guard let data = item as? Data else {
      throw AuthClientError.encodingFailed
    }
    return try JSONDecoder().decode(AuthSession.self, from: data)
  }

  public func save(_ session: AuthSession) throws {
    let encoded = try JSONEncoder().encode(session)
    let updateAttributes: [String: Any] = [
      kSecValueData as String: encoded
    ]
    let updateStatus = SecItemUpdate(
      baseQuery() as CFDictionary,
      updateAttributes as CFDictionary
    )
    if updateStatus == errSecSuccess {
      return
    }
    if updateStatus != errSecItemNotFound {
      throw AuthClientError.keychainFailure(updateStatus)
    }

    var addQuery = baseQuery()
    addQuery[kSecValueData as String] = encoded
    addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
    guard addStatus == errSecSuccess else {
      throw AuthClientError.keychainFailure(addStatus)
    }
  }

  public func clear() throws {
    let status = SecItemDelete(baseQuery() as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw AuthClientError.keychainFailure(status)
    }
  }

  private func baseQuery() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}
