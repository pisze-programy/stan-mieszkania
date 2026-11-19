import AppConfigClient
import AuthClient
import ComposableArchitecture
import Database
import Domain
import Foundation
import SyncEngine
import Testing

@testable import StanMieszkania

@Suite("AppFeature Force-Update Gate Tests")
struct AppFeatureForceUpdateTests {
  private static let userId = "01933e2a-7b40-7000-8000-000000000001"
  private static let minSupportedVersion = "2.0.0"
  private static let baseEpoch: TimeInterval = 1_700_000_000
  private static let baseDate = Date(timeIntervalSince1970: baseEpoch)

  private static let user = UserProfile(
    id: userId,
    displayName: "Jan Kowalski",
    shortTag: "A1B2",
    color: "#007AFF",
    createdAt: baseDate
  )

  @MainActor
  @Test(
    "AppConfig minSupportedAppVersion activates force-update gate while keeping local DB intact")
  func configForceUpdatePreservesLocalData() async throws {
    let database = try makeInMemoryDatabase()
    try ApartmentMutationStore(database: database).saveLocalUser(Self.user)
    let forcedConfig = ResolvedAppConfig(
      config: AppRuntimeConfig(
        minSupportedAppVersion: Self.minSupportedVersion,
        cloudMediaQuotaPerApartment: ContractConstants.defaultCloudMediaQuotaPerApartment,
        jpegCompression: .fallbackDefaults
      ),
      updateStatus: .forceUpdateRequired(minVersion: Self.minSupportedVersion),
      isFromCacheOrFallback: false
    )

    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.authClient.loadStoredSession = {
        AuthSession(firebaseUid: "uid-1", displayName: "Jan Kowalski", bearerToken: "tok")
      }
      $0.themePreference.load = { .system }
      $0.appConfigClient.refresh = { forcedConfig }
      $0.syncEngine.events = { AsyncStream { $0.finish() } }
    }

    await store.send(.task) { $0.onboarding.isLocalDevLoginEnabled = true }
    await store.receive(
      .bootstrapResolved(isAuthenticated: true, currentUser: Self.user, theme: .system)
    ) {
      $0.isBootstrapping = false
      $0.isAuthenticated = true
      $0.currentUser = Self.user
    }
    await store.receive(.appConfigResolved(forcedConfig)) {
      $0.isForceUpdateRequired = true
      $0.forceUpdateMinVersion = Self.minSupportedVersion
    }

    let preservedUser = try ApartmentMutationStore(database: database).fetchCurrentUser()
    #expect(preservedUser == Self.user)
  }

  @MainActor
  @Test("SyncEvent.forceUpdateRequired activates gate and views instantiate cleanly")
  func syncEventForceUpdateAndViewInstantiation() async throws {
    let database = try makeInMemoryDatabase()
    let (stream, continuation) = AsyncStream.makeStream(of: SyncEvent.self)
    let upToDate = ResolvedAppConfig(
      config: .fallbackDefaults,
      updateStatus: .upToDate,
      isFromCacheOrFallback: false
    )

    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.authClient.loadStoredSession = { nil }
      $0.themePreference.load = { .system }
      $0.appConfigClient.refresh = { upToDate }
      $0.syncEngine.events = { stream }
    }

    let taskEffect = await store.send(.task) { $0.onboarding.isLocalDevLoginEnabled = true }
    await store.receive(
      .bootstrapResolved(isAuthenticated: false, currentUser: nil, theme: .system)
    ) {
      $0.isBootstrapping = false
    }
    await store.receive(.appConfigResolved(upToDate))

    continuation.yield(.forceUpdateRequired(minVersion: Self.minSupportedVersion))
    await store.receive(
      .syncEventReceived(.forceUpdateRequired(minVersion: Self.minSupportedVersion))
    ) {
      $0.isForceUpdateRequired = true
      $0.forceUpdateMinVersion = Self.minSupportedVersion
    }

    continuation.finish()
    await taskEffect.cancel()

    let viewStore = Store(initialState: AppFeature.State()) { AppFeature() }
    _ = (
      AppRootView(store: viewStore),
      ForceUpdateGateView(minVersion: Self.minSupportedVersion),
    )
  }
}
