import CoreGraphics
import Domain
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum SyntheticImageFixtures {
  static let mediaId = "01933e2a-7b40-7000-8000-000000000101"
  static let remoteMediaId = "01933e2a-7b40-7000-8000-000000000102"
  static let largeWidth = 4_000
  static let largeHeight = 3_000
  static let expectedScaledWidth = 3_000
  static let expectedScaledHeight = 2_250
  static let mediumWidth = 1_200
  static let mediumHeight = 800
  static let thumbnailMaxSize = 300
  static let expectedThumbnailHeight = 200
  static let tightMaxBytes = 300_000
  static let impossibleMaxBytes = 100
  static let highQuality: Double = 0.95
  static let bitsPerComponent = 8
  static let bytesPerPixel = 4
  static let colorChannelMax: UInt8 = 255
  static let stripeStride = 17
  static let secondaryStripeStride = 31
  static let blueMultiplier = 7
  static let byteModulo = 256
  static let orientationRight = 6
  static let sampleEpochSeconds: TimeInterval = 1_730_000_000
  static let sampleNow = Date(timeIntervalSince1970: sampleEpochSeconds)
  static let warsawLat = 52.2297
  static let warsawLng = 21.0122
  static let gpsAccuracyM = 6.5
  static let deviceLat = 50.0647
  static let deviceLng = 19.9450
  static let coordTolerance = 0.0001
  static let exifDateOriginal = "2025:11:17 14:30:00"
  static let exifOffsetOriginal = "+01:00"
  static let cameraMake = "Apple"
  static let cameraModel = "iPhone 17 Pro"
  static let warsawTimeZone = "Europe/Warsaw"

  static func makeSyntheticJpegData(
    width: Int,
    height: Int,
    includeExifAndGps: Bool,
    orientation: Int? = nil
  ) throws -> Data {
    let image = try makeNoisyCGImage(width: width, height: height)
    let mutableData = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        mutableData as CFMutableData,
        UTType.jpeg.identifier as CFString,
        1,
        nil
      )
    else {
      throw FixtureError.destinationCreationFailed
    }

    var options: [CFString: Any] = [
      kCGImageDestinationLossyCompressionQuality: highQuality
    ]
    if let orientation {
      options[kCGImagePropertyOrientation] = orientation
    }
    if includeExifAndGps {
      options[kCGImagePropertyExifDictionary] = [
        kCGImagePropertyExifDateTimeOriginal: exifDateOriginal,
        kCGImagePropertyExifOffsetTimeOriginal: exifOffsetOriginal,
      ]
      options[kCGImagePropertyTIFFDictionary] = [
        kCGImagePropertyTIFFMake: cameraMake,
        kCGImagePropertyTIFFModel: cameraModel,
      ]
      options[kCGImagePropertyGPSDictionary] = [
        kCGImagePropertyGPSLatitude: warsawLat,
        kCGImagePropertyGPSLatitudeRef: "N",
        kCGImagePropertyGPSLongitude: warsawLng,
        kCGImagePropertyGPSLongitudeRef: "E",
        kCGImagePropertyGPSHPositioningError: gpsAccuracyM,
      ]
    }

    CGImageDestinationAddImage(destination, image, options as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      throw FixtureError.finalizationFailed
    }
    return mutableData as Data
  }

  static func readImageProperties(from jpegData: Data) -> [CFString: Any] {
    guard let source = CGImageSourceCreateWithData(jpegData as CFData, nil) else {
      return [:]
    }
    return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
  }

  private static func makeNoisyCGImage(width: Int, height: Int) throws -> CGImage {
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

    for y in 0..<height {
      for x in 0..<width {
        let offset = y * bytesPerRow + x * bytesPerPixel
        let red = UInt8((x * stripeStride + y * secondaryStripeStride) % byteModulo)
        let green = UInt8(((x ^ y) * stripeStride) % byteModulo)
        let blue = UInt8(((x + y) * blueMultiplier) % byteModulo)
        pixels[offset] = red
        pixels[offset + 1] = green
        pixels[offset + 1 + 1] = blue
        pixels[offset + 1 + 1 + 1] = colorChannelMax
      }
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    let data = Data(pixels)
    guard
      let provider = CGDataProvider(data: data as CFData),
      let image = CGImage(
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bitsPerPixel: bitsPerComponent * bytesPerPixel,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo,
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
      )
    else {
      throw FixtureError.cgImageCreationFailed
    }
    return image
  }

  private enum FixtureError: Error {
    case cgImageCreationFailed
    case destinationCreationFailed
    case finalizationFailed
  }
}
