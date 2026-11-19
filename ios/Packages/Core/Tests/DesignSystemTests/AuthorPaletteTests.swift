import SwiftUI
import Testing

@testable import DesignSystem

@Suite("AuthorPalette Tests")
struct AuthorPaletteTests {
  private enum Fixtures {
    static let greenHex = "#34C759"
    static let expectedRed = 52.0 / 255.0
    static let expectedGreen = 199.0 / 255.0
    static let expectedBlue = 89.0 / 255.0
    static let tolerance = 0.0001
    static let whiteHex = "#FFFFFF"
    static let blackHex = "#000000"
    static let primaryBlueHex = "#007AFF"
  }

  @Test("Parses valid #RRGGBB hex values and rejects malformed strings")
  func parsesHexValues() throws {
    let parsed = try #require(AuthorPalette.rgbComponents(fromHex: Fixtures.greenHex))
    #expect(abs(parsed.red - Fixtures.expectedRed) < Fixtures.tolerance)
    #expect(abs(parsed.green - Fixtures.expectedGreen) < Fixtures.tolerance)
    #expect(abs(parsed.blue - Fixtures.expectedBlue) < Fixtures.tolerance)

    let unprefixed = try #require(AuthorPalette.rgbComponents(fromHex: "34C759"))
    #expect(unprefixed == parsed)

    #expect(AuthorPalette.rgbComponents(fromHex: "#12345") == nil)
    #expect(AuthorPalette.rgbComponents(fromHex: "ZZZZZZ") == nil)
  }

  @Test("Computes WCAG contrast foreground color for light and dark backgrounds")
  func computesContrastingForeground() {
    #expect(AuthorPalette.isLightColor(hex: Fixtures.whiteHex))
    #expect(!AuthorPalette.isLightColor(hex: Fixtures.blackHex))
    #expect(!AuthorPalette.isLightColor(hex: Fixtures.primaryBlueHex))

    #expect(AuthorPalette.contrastingForegroundColor(forBackgroundHex: Fixtures.whiteHex) == .black)
    #expect(AuthorPalette.contrastingForegroundColor(forBackgroundHex: Fixtures.blackHex) == .white)
    #expect(
      AuthorPalette.contrastingForegroundColor(forBackgroundHex: Fixtures.primaryBlueHex) == .white
    )
  }
}
