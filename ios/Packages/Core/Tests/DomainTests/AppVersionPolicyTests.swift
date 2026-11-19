import Testing

@testable import Domain

@Suite("AppVersionPolicy Tests")
struct AppVersionPolicyTests {
  @Test("Compares major, minor, and patch versions per SemVer 2.0.0")
  func comparesCoreSemVer() {
    #expect(
      AppVersionPolicy.isUpdateRequired(currentVersion: "1.0.0", minSupportedVersion: "1.0.1")
    )
    #expect(
      AppVersionPolicy.isUpdateRequired(currentVersion: "1.9.9", minSupportedVersion: "1.10.0")
    )
    #expect(
      AppVersionPolicy.isUpdateRequired(currentVersion: "1.9.9", minSupportedVersion: "2.0.0")
    )
    #expect(
      !AppVersionPolicy.isUpdateRequired(currentVersion: "1.0.0", minSupportedVersion: "1.0.0")
    )
    #expect(
      !AppVersionPolicy.isUpdateRequired(currentVersion: "1.2.0", minSupportedVersion: "1.1.9")
    )
  }

  @Test("Handles pre-release precedence, build metadata, and malformed inputs")
  func handlesPreReleaseAndBuildMetadata() {
    #expect(
      AppVersionPolicy.isUpdateRequired(
        currentVersion: "1.0.0-beta.1", minSupportedVersion: "1.0.0")
    )
    #expect(
      AppVersionPolicy.isUpdateRequired(
        currentVersion: "1.0.0-alpha.1",
        minSupportedVersion: "1.0.0-alpha.beta"
      )
    )
    #expect(
      AppVersionPolicy.isUpdateRequired(
        currentVersion: "1.0.0-alpha",
        minSupportedVersion: "1.0.0-alpha.1"
      )
    )
    #expect(
      !AppVersionPolicy.isUpdateRequired(
        currentVersion: "1.0.0+build.42",
        minSupportedVersion: "1.0.0"
      )
    )
    #expect(
      !AppVersionPolicy.isUpdateRequired(currentVersion: "invalid", minSupportedVersion: "1.0.0")
    )
    #expect(
      !AppVersionPolicy.isUpdateRequired(currentVersion: "1.0.0", minSupportedVersion: "invalid")
    )
  }
}
