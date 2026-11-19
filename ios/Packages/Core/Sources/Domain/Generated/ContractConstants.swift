import Foundation

public enum ContractConstants: Sendable {
  public static let displayNameMinLength: Int = 1
  public static let displayNameMaxLength: Int = 80
  public static let apartmentNameMinLength: Int = 1
  public static let apartmentNameMaxLength: Int = 100
  public static let apartmentStreetMinLength: Int = 1
  public static let apartmentStreetMaxLength: Int = 120
  public static let apartmentCityMinLength: Int = 1
  public static let apartmentCityMaxLength: Int = 80
  public static let inviteCodeRawLength: Int = 8
  public static let inviteCodeGroupLength: Int = 4
  public static let entryTextMinLength: Int = 1
  public static let entryTextMaxLength: Int = 4000
  public static let sha256HexLength: Int = 64
  public static let defaultCloudMediaQuotaPerApartment: Int = 250
  public static let defaultJpegMaxDimensionPx: Int = 3000
  public static let defaultJpegMaxBytes: Int = 3145728
  public static let inviteCodeAlphabet: String = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
  public static let markerCoordMin: Double = 0.0
  public static let markerCoordMax: Double = 1.0
  public static let authorColorPalette: [String] = [
    "#007AFF",
    "#34C759",
    "#FF9500",
    "#AF52DE",
    "#FF2D55",
    "#5856D6",
    "#00C7BE",
    "#FF3B30",
  ]
  public static let defaultJpegQuality: Double = 0.8
  public static let defaultMinSupportedAppVersion: String = "1.0.0"
}
