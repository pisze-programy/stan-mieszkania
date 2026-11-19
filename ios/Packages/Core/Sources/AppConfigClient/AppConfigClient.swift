import APIClient
import Dependencies
import DependenciesMacros
import Domain
import Foundation

@DependencyClient
public struct AppConfigClient: Sendable {
  public var loadCachedOrDefault: @Sendable () -> AppRuntimeConfig = { .fallbackDefaults }
  public var refresh: @Sendable () async -> ResolvedAppConfig = {
    ResolvedAppConfig(
      config: .fallbackDefaults,
      updateStatus: .upToDate,
      isFromCacheOrFallback: true
    )
  }
  public var evaluateUpdateStatus: @Sendable (AppRuntimeConfig) -> AppUpdateStatus = { _ in
    .upToDate
  }

  public static func live(
    fetchRemoteConfig: @escaping @Sendable () async throws -> AppRuntimeConfig,
    cacheStore: any AppConfigCacheStore = UserDefaultsAppConfigCacheStore(),
    currentAppVersion: String = Self.bundleAppVersion()
  ) -> Self {
    let evaluate: @Sendable (AppRuntimeConfig) -> AppUpdateStatus = { config in
      // Architecture A19: Compare client version against minSupportedAppVersion via SemVer policy.
      if AppVersionPolicy.isUpdateRequired(
        currentVersion: currentAppVersion,
        minSupportedVersion: config.minSupportedAppVersion
      ) {
        return .forceUpdateRequired(minVersion: config.minSupportedAppVersion)
      }
      return .upToDate
    }

    return Self(
      loadCachedOrDefault: {
        // Architecture A18: Fall back cleanly to compiled defaults when cache is empty.
        cacheStore.load() ?? .fallbackDefaults
      },
      refresh: {
        do {
          let remote = try await fetchRemoteConfig()
          cacheStore.save(remote)
          return ResolvedAppConfig(
            config: remote,
            updateStatus: evaluate(remote),
            isFromCacheOrFallback: false
          )
        } catch {
          let cached = cacheStore.load() ?? .fallbackDefaults
          return ResolvedAppConfig(
            config: cached,
            updateStatus: evaluate(cached),
            isFromCacheOrFallback: true
          )
        }
      },
      evaluateUpdateStatus: evaluate
    )
  }

  public static func bundleAppVersion(bundle: Bundle = .main) -> String {
    let value =
      bundle.object(
        forInfoDictionaryKey: AppConfigClientConstants.defaultBundleVersionKey
      ) as? String
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let trimmed, !trimmed.isEmpty {
      return trimmed
    }
    return AppConfigClientConstants.fallbackAppVersion
  }
}

extension AppConfigClient: DependencyKey {
  public static var liveValue: AppConfigClient {
    .live(
      fetchRemoteConfig: {
        @Dependency(\.apiClient) var apiClient
        return try await apiClient.getPublicConfig()
      }
    )
  }

  public static var testValue: AppConfigClient {
    AppConfigClient()
  }
}

extension DependencyValues {
  public var appConfigClient: AppConfigClient {
    get { self[AppConfigClient.self] }
    set { self[AppConfigClient.self] = newValue }
  }
}
