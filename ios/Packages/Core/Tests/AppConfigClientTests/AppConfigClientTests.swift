import AppConfigClient
import Dependencies
import Domain
import Foundation
import Testing

@Suite("AppConfigClient Cache, Offline Fallback, and Force Update Gate Tests")
struct AppConfigClientTests {
  private enum Fixtures {
    static let customQuota = 500
    static let customMaxDim = 2_400
    static let customQuality: Double = 0.75
    static let customMaxBytes = 2_000_000
    static let currentVersion = "1.1.0"
    static let newerMinVersion = "1.2.0"
    static let compatibleMinVersion = "1.0.0"

    static func makeRemoteConfig(minVersion: String) -> AppRuntimeConfig {
      AppRuntimeConfig(
        minSupportedAppVersion: minVersion,
        cloudMediaQuotaPerApartment: customQuota,
        jpegCompression: JpegCompressionSettings(
          maxDimensionPx: customMaxDim,
          quality: customQuality,
          maxBytes: customMaxBytes
        )
      )
    }
  }

  private enum StubNetworkError: Error {
    case offline
  }

  @Test("Falls back to compiled defaults when offline and cache is empty")
  func fallsBackToCompiledDefaultsOffline() async {
    let cache = InMemoryAppConfigCacheStore()
    let client = AppConfigClient.live(
      fetchRemoteConfig: { throw StubNetworkError.offline },
      cacheStore: cache,
      currentAppVersion: Fixtures.currentVersion
    )

    #expect(client.loadCachedOrDefault() == .fallbackDefaults)

    let resolved = await client.refresh()
    #expect(resolved.config == .fallbackDefaults)
    #expect(resolved.isFromCacheOrFallback)
    #expect(resolved.updateStatus == .upToDate)
  }

  @Test("Caches remote config and enforces forceUpdateRequired even when subsequently offline")
  func cachesRemoteConfigAndEvaluatesVersionGate() async {
    let suiteName = "pl.stanmieszkania.tests.\(UUID().uuidString)"
    let cache = UserDefaultsAppConfigCacheStore(suiteName: suiteName)
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

    let remoteConfig = Fixtures.makeRemoteConfig(minVersion: Fixtures.newerMinVersion)
    let onlineClient = AppConfigClient.live(
      fetchRemoteConfig: { remoteConfig },
      cacheStore: cache,
      currentAppVersion: Fixtures.currentVersion
    )

    let onlineResolved = await onlineClient.refresh()
    #expect(onlineResolved.config == remoteConfig)
    #expect(!onlineResolved.isFromCacheOrFallback)
    #expect(
      onlineResolved.updateStatus == .forceUpdateRequired(minVersion: Fixtures.newerMinVersion)
    )
    #expect(onlineClient.loadCachedOrDefault() == remoteConfig)

    let offlineClient = AppConfigClient.live(
      fetchRemoteConfig: { throw StubNetworkError.offline },
      cacheStore: cache,
      currentAppVersion: Fixtures.currentVersion
    )
    let offlineResolved = await offlineClient.refresh()
    #expect(offlineResolved.config == remoteConfig)
    #expect(offlineResolved.isFromCacheOrFallback)
    #expect(
      offlineResolved.updateStatus == .forceUpdateRequired(minVersion: Fixtures.newerMinVersion)
    )
  }

  @Test("Resolves compatible remote config as upToDate via DependencyValues")
  func resolvesCompatibleConfigAsUpToDate() async {
    let cache = InMemoryAppConfigCacheStore()
    let compatible = Fixtures.makeRemoteConfig(minVersion: Fixtures.compatibleMinVersion)

    await withDependencies {
      $0.appConfigClient = .live(
        fetchRemoteConfig: { compatible },
        cacheStore: cache,
        currentAppVersion: Fixtures.currentVersion
      )
    } operation: {
      @Dependency(\.appConfigClient) var appConfigClient
      let resolved = await appConfigClient.refresh()
      #expect(resolved.config == compatible)
      #expect(resolved.updateStatus == .upToDate)
      #expect(!resolved.isFromCacheOrFallback)
    }
  }
}
