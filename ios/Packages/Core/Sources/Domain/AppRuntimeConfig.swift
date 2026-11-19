import Foundation

public struct JpegCompressionSettings: Codable, Sendable, Equatable, Hashable {
  public let maxDimensionPx: Int
  public let quality: Double
  public let maxBytes: Int

  public init(
    maxDimensionPx: Int,
    quality: Double,
    maxBytes: Int
  ) {
    self.maxDimensionPx = maxDimensionPx
    self.quality = quality
    self.maxBytes = maxBytes
  }

  public static let fallbackDefaults = JpegCompressionSettings(
    maxDimensionPx: ContractConstants.defaultJpegMaxDimensionPx,
    quality: ContractConstants.defaultJpegQuality,
    maxBytes: ContractConstants.defaultJpegMaxBytes
  )
}

public struct AppRuntimeConfig: Codable, Sendable, Equatable, Hashable {
  public let minSupportedAppVersion: String
  public let cloudMediaQuotaPerApartment: Int
  public let jpegCompression: JpegCompressionSettings

  public init(
    minSupportedAppVersion: String,
    cloudMediaQuotaPerApartment: Int,
    jpegCompression: JpegCompressionSettings
  ) {
    self.minSupportedAppVersion = minSupportedAppVersion
    self.cloudMediaQuotaPerApartment = cloudMediaQuotaPerApartment
    self.jpegCompression = jpegCompression
  }

  public static let fallbackDefaults = AppRuntimeConfig(
    minSupportedAppVersion: ContractConstants.defaultMinSupportedAppVersion,
    cloudMediaQuotaPerApartment: ContractConstants.defaultCloudMediaQuotaPerApartment,
    jpegCompression: .fallbackDefaults
  )
}
