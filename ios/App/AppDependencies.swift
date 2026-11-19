import APIClient
import AppConfigClient
import AuthClient
import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import MediaStorage
import SQLiteData
import SyncEngine

public enum AppAuthMode: String, Equatable, Sendable {
  case local
  case firebase
}

public struct AppEnvironmentConfig: Equatable, Sendable {
  public let apiBaseURL: URL
  public let authMode: AppAuthMode
  public let appVersion: String

  public var isLocalDevLoginEnabled: Bool {
    authMode == .local
  }

  public init(apiBaseURL: URL, authMode: AppAuthMode, appVersion: String) {
    self.apiBaseURL = apiBaseURL
    self.authMode = authMode
    self.appVersion = appVersion
  }

  public static func fromBundle(_ bundle: Bundle = .main) -> Self {
    let rawURL = (bundle.object(forInfoDictionaryKey: AppConstants.apiBaseURLInfoKey) as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let fallbackURL =
      URL(string: APIClientConstants.defaultBaseURLString) ?? URL(fileURLWithPath: "/")
    let resolvedURL = rawURL.flatMap(URL.init(string:)) ?? fallbackURL

    let rawAuthMode =
      (bundle.object(forInfoDictionaryKey: AppConstants.authModeInfoKey) as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    let authMode = rawAuthMode.flatMap(AppAuthMode.init(rawValue:)) ?? .firebase

    let rawVersion =
      (bundle.object(forInfoDictionaryKey: AppConstants.bundleShortVersionInfoKey) as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let appVersion =
      (rawVersion?.isEmpty == false ? rawVersion : nil)
      ?? AppConstants.fallbackAppVersion

    return Self(apiBaseURL: resolvedURL, authMode: authMode, appVersion: appVersion)
  }
}

public enum AppEnvironmentKey: DependencyKey {
  public static var liveValue: AppEnvironmentConfig {
    .fromBundle(.main)
  }

  public static var testValue: AppEnvironmentConfig {
    AppEnvironmentConfig(
      apiBaseURL: URL(string: APIClientConstants.defaultBaseURLString) ?? URL(fileURLWithPath: "/"),
      authMode: .local,
      appVersion: AppConstants.fallbackAppVersion
    )
  }
}

extension DependencyValues {
  public var appEnvironment: AppEnvironmentConfig {
    get { self[AppEnvironmentKey.self] }
    set { self[AppEnvironmentKey.self] = newValue }
  }
}

enum AppDependencies {
  static var isRunningTests: Bool {
    ProcessInfo.processInfo.environment[AppConstants.xcTestConfigurationEnvKey] != nil
  }

  static func configureLive(_ dependencies: inout DependencyValues, bundle: Bundle = .main) {
    let environment = AppEnvironmentConfig.fromBundle(bundle)
    let database = makeLiveDatabase()
    let mediaStorage = makeLiveMediaStorage()
    let authClient = makeLiveAuthClient(environment: environment, bundle: bundle)
    let apiClient = APIClient.live(
      serverURL: environment.apiBaseURL,
      appVersion: environment.appVersion,
      tokenProvider: {
        try? await authClient.validBearerToken()
      }
    )
    let appConfigClient = AppConfigClient.live(
      fetchRemoteConfig: {
        try await apiClient.getPublicConfig()
      },
      currentAppVersion: environment.appVersion
    )
    let syncActor = SyncEngineActor(
      database: database,
      apiClient: apiClient,
      mediaStorage: mediaStorage,
      objectTransfer: .liveValue
    )

    dependencies.appEnvironment = environment
    dependencies.defaultDatabase = database
    dependencies.mediaStorage = mediaStorage
    dependencies.authClient = authClient
    dependencies.apiClient = apiClient
    dependencies.appConfigClient = appConfigClient
    dependencies.syncEngine = .live(actor: syncActor)
    dependencies.themePreference = .live
    dependencies.haptics = .live
  }

  static func makeLiveAuthClient(
    environment: AppEnvironmentConfig,
    bundle: Bundle = .main
  ) -> AuthClient {
    switch environment.authMode {
    case .local:
      return .live()
    case .firebase:
      let firebaseClient = FirebaseIdentityToolkitClient(
        apiKeyProvider: {
          FirebaseAuthConfiguration.load(from: bundle)?.apiKey
        }
      )
      return .liveFirebase(firebaseClient: firebaseClient)
    }
  }

  private static func makeLiveDatabase() -> any DatabaseWriter {
    if let appDatabase = try? makeAppDatabase() {
      return appDatabase
    }
    if let fallback = try? makeInMemoryDatabase() {
      return fallback
    }
    fatalError("Unable to initialize SQLiteData database")
  }

  private static func makeLiveMediaStorage() -> MediaStorageClient {
    if let appSupport = try? FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    ) {
      let directory = appSupport.appendingPathComponent(
        MediaStorageConstants.defaultCacheFolderName,
        isDirectory: true
      )
      return .live(baseDirectory: directory)
    }
    return .liveValue
  }
}
