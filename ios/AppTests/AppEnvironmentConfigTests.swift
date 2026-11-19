import Domain
import Foundation
import Testing

@testable import StanMieszkania

@Suite("AppEnvironmentConfig & Info.plist Tests")
struct AppEnvironmentConfigTests {
  private static let expectedDefaultURL =
    "https://stanmieszkania-api-production.stanmieszkania-api.workers.dev"
  private static let expectedVersion = "1.0.0"
  private static let higherMinVersion = "1.0.1"
  private static let cameraUsageKey = "NSCameraUsageDescription"
  private static let locationUsageKey = "NSLocationWhenInUseUsageDescription"
  private static let photoLibraryUsageKey = "NSPhotoLibraryUsageDescription"

  @Test("Debug bundle resolves Cloudflare production URL, Firebase auth, SemVer, and TCC keys")
  func debugBundleResolvesConfigAndTCCKeys() {
    let bundle = Bundle.main
    let config = AppEnvironmentConfig.fromBundle(bundle)

    #expect(config.apiBaseURL.absoluteString == Self.expectedDefaultURL)
    #expect(config.authMode == .firebase)
    #expect(config.appVersion == Self.expectedVersion)
    #expect(
      AppVersionPolicy.isUpdateRequired(
        currentVersion: config.appVersion,
        minSupportedVersion: Self.higherMinVersion
      )
    )
    #expect(
      !AppVersionPolicy.isUpdateRequired(
        currentVersion: config.appVersion,
        minSupportedVersion: Self.expectedVersion
      )
    )

    for key in [Self.cameraUsageKey, Self.locationUsageKey, Self.photoLibraryUsageKey] {
      let value = (bundle.object(forInfoDictionaryKey: key) as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
      #expect(value?.isEmpty == false)
    }

    let manifestURL = bundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy")
    #expect(manifestURL != nil)
  }
}
