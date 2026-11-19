import Domain
import SwiftUI

public struct RGBComponents: Sendable, Equatable {
  public let red: Double
  public let green: Double
  public let blue: Double
}

public enum AuthorPalette: Sendable {
  private static let hashPrefix: Character = "#"
  private static let expectedHexLength: Int = 6
  private static let hexRadix: Int = 16
  private static let maxChannelValue: Double = 255.0
  private static let redShift: UInt32 = 16
  private static let greenShift: UInt32 = 8
  private static let channelMask: UInt32 = 0xFF
  private static let fallbackBlueComponent: Double = 1.0
  private static let fallbackGreenComponent: Double = 0.47843137254901963

  private static let srgbLinearThreshold: Double = 0.03928
  private static let srgbLowDivisor: Double = 12.92
  private static let srgbGammaOffset: Double = 0.055
  private static let srgbGammaDivisor: Double = 1.055
  private static let srgbGammaExponent: Double = 2.4
  private static let luminanceRedWeight: Double = 0.2126
  private static let luminanceGreenWeight: Double = 0.7152
  private static let luminanceBlueWeight: Double = 0.0722
  private static let lightLuminanceThreshold: Double = 0.5

  private static let defaultComponents = RGBComponents(
    red: 0,
    green: fallbackGreenComponent,
    blue: fallbackBlueComponent
  )

  public static func color(fromHex hex: String) -> Color {
    let components = rgbComponents(fromHex: hex) ?? defaultComponents
    return Color(red: components.red, green: components.green, blue: components.blue)
  }

  public static func rgbComponents(fromHex hex: String) -> RGBComponents? {
    let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    let stripped = trimmed.first == hashPrefix ? String(trimmed.dropFirst()) : trimmed
    guard
      stripped.count == expectedHexLength,
      let value = UInt32(stripped, radix: hexRadix)
    else {
      return nil
    }

    let red = Double((value >> redShift) & channelMask) / maxChannelValue
    let green = Double((value >> greenShift) & channelMask) / maxChannelValue
    let blue = Double(value & channelMask) / maxChannelValue
    return RGBComponents(red: red, green: green, blue: blue)
  }

  public static func isLightColor(hex: String) -> Bool {
    let components = rgbComponents(fromHex: hex) ?? defaultComponents
    let luminance =
      luminanceRedWeight * linearizeChannel(components.red)
      + luminanceGreenWeight * linearizeChannel(components.green)
      + luminanceBlueWeight * linearizeChannel(components.blue)
    return luminance > lightLuminanceThreshold
  }

  public static func contrastingForegroundColor(forBackgroundHex hex: String) -> Color {
    isLightColor(hex: hex) ? .black : .white
  }

  private static func linearizeChannel(_ channel: Double) -> Double {
    if channel <= srgbLinearThreshold {
      return channel / srgbLowDivisor
    }
    return pow((channel + srgbGammaOffset) / srgbGammaDivisor, srgbGammaExponent)
  }
}
