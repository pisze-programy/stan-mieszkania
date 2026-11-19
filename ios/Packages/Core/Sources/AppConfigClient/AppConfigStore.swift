import Domain
import Foundation
import Synchronization

public enum AppUpdateStatus: Equatable, Hashable, Sendable {
  case upToDate
  case forceUpdateRequired(minVersion: String)
}

public struct ResolvedAppConfig: Equatable, Hashable, Sendable {
  public let config: AppRuntimeConfig
  public let updateStatus: AppUpdateStatus
  public let isFromCacheOrFallback: Bool

  public init(
    config: AppRuntimeConfig,
    updateStatus: AppUpdateStatus,
    isFromCacheOrFallback: Bool
  ) {
    self.config = config
    self.updateStatus = updateStatus
    self.isFromCacheOrFallback = isFromCacheOrFallback
  }
}

public protocol AppConfigCacheStore: Sendable {
  func load() -> AppRuntimeConfig?
  func save(_ config: AppRuntimeConfig)
}

public final class InMemoryAppConfigCacheStore: AppConfigCacheStore, Sendable {
  private let storage: Mutex<AppRuntimeConfig?>

  public init(initialConfig: AppRuntimeConfig? = nil) {
    self.storage = Mutex(initialConfig)
  }

  public func load() -> AppRuntimeConfig? {
    storage.withLock { $0 }
  }

  public func save(_ config: AppRuntimeConfig) {
    storage.withLock { $0 = config }
  }
}

public struct UserDefaultsAppConfigCacheStore: AppConfigCacheStore, Sendable {
  private let suiteName: String?
  private let key: String

  public init(
    suiteName: String? = nil,
    key: String = AppConfigClientConstants.cacheKey
  ) {
    self.suiteName = suiteName
    self.key = key
  }

  public func load() -> AppRuntimeConfig? {
    guard
      let defaults = resolveDefaults(),
      let data = defaults.data(forKey: key)
    else {
      return nil
    }
    return try? JSONDecoder().decode(AppRuntimeConfig.self, from: data)
  }

  public func save(_ config: AppRuntimeConfig) {
    guard
      let defaults = resolveDefaults(),
      let data = try? JSONEncoder().encode(config)
    else {
      return
    }
    defaults.set(data, forKey: key)
  }

  private func resolveDefaults() -> UserDefaults? {
    if let suiteName {
      return UserDefaults(suiteName: suiteName)
    }
    return UserDefaults.standard
  }
}
