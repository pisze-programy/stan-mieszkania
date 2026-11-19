import Foundation

public enum AppConfigClientConstants: Sendable {
  public static let cacheKey: String = "pl.stanmieszkania.app.runtime-config"
  public static let defaultBundleVersionKey: String = "CFBundleShortVersionString"
  public static let fallbackAppVersion: String = "1.0.0"
}
