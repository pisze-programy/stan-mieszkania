import CoreGraphics
import Domain
import Foundation
import ImageIO
import MediaStorage
import Testing
import UniformTypeIdentifiers

@Suite("OpaqueImageConverter and Alpha-Safe JPEG Encoding Tests")
struct OpaqueImageConverterTests {
  private static let testWidth = 320
  private static let testHeight = 240
  private static let bitsPerComponent = 8
  private static let bytesPerPixel = 4
  private static let channelRed: UInt8 = 180
  private static let channelGreen: UInt8 = 90
  private static let channelBlue: UInt8 = 40
  private static let channelAlpha: UInt8 = 255
  private static let greenOffset = 1
  private static let blueOffset = 2
  private static let alphaOffset = 3

  @Test("Strips premultipliedLast alpha to noneSkipLast and preserves already-opaque images")
  func stripsAlphaAndPreservesOpaqueImages() throws {
    let rgbaImage = try makeImage(alphaInfo: .premultipliedLast)
    #expect(rgbaImage.alphaInfo == .premultipliedLast)

    let stripped = OpaqueImageConverter.makeOpaqueIfNeeded(rgbaImage)
    #expect(stripped.alphaInfo == .noneSkipLast)
    #expect(stripped.width == Self.testWidth)
    #expect(stripped.height == Self.testHeight)

    let alreadyOpaque = try makeImage(alphaInfo: .noneSkipLast)
    let unchanged = OpaqueImageConverter.makeOpaqueIfNeeded(alreadyOpaque)
    #expect(unchanged.alphaInfo == .noneSkipLast)
    #expect(unchanged.width == Self.testWidth)
    #expect(unchanged.height == Self.testHeight)
  }

  @Test("Ingests RGBA PNG input cleanly into an alpha-free JPEG")
  func ingestsRgbaPngIntoAlphaFreeJpeg() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString,
      isDirectory: true
    )
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let store = LocalMediaStore(baseDirectory: tempDir)

    let pngData = try makeRgbaPngData()
    let artifact = try store.ingestPhoto(
      PhotoIngestRequest(
        mediaId: SyntheticImageFixtures.mediaId,
        rawData: pngData,
        source: .imported,
        now: SyntheticImageFixtures.sampleNow,
        timeZoneIdentifier: SyntheticImageFixtures.warsawTimeZone
      )
    )

    #expect(artifact.width == Self.testWidth)
    #expect(artifact.height == Self.testHeight)
    let savedData = try store.loadPhotoData(mediaId: SyntheticImageFixtures.mediaId)
    #expect(SHA256Hasher.hexDigest(of: savedData) == artifact.sha256)
    let props = SyntheticImageFixtures.readImageProperties(from: savedData)
    let hasAlpha = (props[kCGImagePropertyHasAlpha] as? Bool) ?? false
    #expect(!hasAlpha)
  }

  private func makeRgbaPngData() throws -> Data {
    let rgbaImage = try makeImage(alphaInfo: .premultipliedLast)
    let mutableData = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        mutableData as CFMutableData,
        UTType.png.identifier as CFString,
        1,
        nil
      )
    else {
      throw TestError.pngEncodingFailed
    }
    CGImageDestinationAddImage(destination, rgbaImage, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw TestError.pngEncodingFailed
    }
    return mutableData as Data
  }

  private func makeImage(alphaInfo: CGImageAlphaInfo) throws -> CGImage {
    let bytesPerRow = Self.testWidth * Self.bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: bytesPerRow * Self.testHeight)
    for y in 0..<Self.testHeight {
      for x in 0..<Self.testWidth {
        let offset = y * bytesPerRow + x * Self.bytesPerPixel
        pixels[offset] = Self.channelRed
        pixels[offset + Self.greenOffset] = Self.channelGreen
        pixels[offset + Self.blueOffset] = Self.channelBlue
        pixels[offset + Self.alphaOffset] = Self.channelAlpha
      }
    }
    let data = Data(pixels)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: alphaInfo.rawValue)
    guard
      let provider = CGDataProvider(data: data as CFData),
      let image = CGImage(
        width: Self.testWidth,
        height: Self.testHeight,
        bitsPerComponent: Self.bitsPerComponent,
        bitsPerPixel: Self.bitsPerComponent * Self.bytesPerPixel,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo,
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
      )
    else {
      throw TestError.imageCreationFailed
    }
    return image
  }

  private enum TestError: Error {
    case imageCreationFailed
    case pngEncodingFailed
  }
}
