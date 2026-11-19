import Dependencies
import Foundation

public enum AppThemePreference: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
  case system
  case light
  case dark
}

public struct ThemePreferenceClient: Sendable {
  public static let defaultsKey: String = "stanmieszkania.app.themePreference"

  public var load: @Sendable () -> AppThemePreference
  public var save: @Sendable (_ preference: AppThemePreference) -> Void

  public init(
    load: @escaping @Sendable () -> AppThemePreference,
    save: @escaping @Sendable (_ preference: AppThemePreference) -> Void
  ) {
    self.load = load
    self.save = save
  }

  public static let live = ThemePreferenceClient(
    load: {
      guard
        let raw = UserDefaults.standard.string(forKey: defaultsKey),
        let preference = AppThemePreference(rawValue: raw)
      else {
        return .system
      }
      return preference
    },
    save: { preference in
      UserDefaults.standard.set(preference.rawValue, forKey: defaultsKey)
    }
  )

  public static let noop = ThemePreferenceClient(
    load: { .system },
    save: { _ in }
  )
}

extension ThemePreferenceClient: DependencyKey {
  public static var liveValue: ThemePreferenceClient {
    .live
  }

  public static var testValue: ThemePreferenceClient {
    .noop
  }
}

extension DependencyValues {
  public var themePreference: ThemePreferenceClient {
    get { self[ThemePreferenceClient.self] }
    set { self[ThemePreferenceClient.self] = newValue }
  }
}
