import SwiftUI

public enum MarkerPalette: Sendable {
  public static let hexes: [String] = [
    "#FF3B30",
    "#0A84FF",
    "#30A14E",
    "#FF9500",
    "#AF52DE",
    "#0FA3B1",
    "#FF2D55",
    "#5856D6",
  ]

  public static func hex(forMarkerNumber number: Int) -> String {
    hexes[(max(number, 1) - 1) % hexes.count]
  }

  public static func color(forMarkerNumber number: Int) -> Color {
    AuthorPalette.color(fromHex: hex(forMarkerNumber: number))
  }
}
