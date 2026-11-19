import CoreGraphics

public enum OpaqueImageConverter: Sendable {
  private static let bitsPerComponent = 8
  private static let automaticBytesPerRow = 0
  private static let originCoordinate: CGFloat = 0
  private static let whiteChannel: CGFloat = 1
  private static let opaqueAlpha: CGFloat = 1

  public static func makeOpaqueIfNeeded(_ cgImage: CGImage) -> CGImage {
    switch cgImage.alphaInfo {
    case .none, .noneSkipLast, .noneSkipFirst:
      return cgImage
    case .premultipliedLast, .premultipliedFirst, .last, .first, .alphaOnly:
      break
    @unknown default:
      break
    }

    let preferredSpace = preferredRGBColorSpace(for: cgImage)
    let fallbackSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    guard
      let context = makeOpaqueRGBContext(
        width: cgImage.width,
        height: cgImage.height,
        colorSpace: preferredSpace
      )
        ?? makeOpaqueRGBContext(
          width: cgImage.width,
          height: cgImage.height,
          colorSpace: fallbackSpace
        )
    else {
      return cgImage
    }

    let bounds = CGRect(
      x: originCoordinate,
      y: originCoordinate,
      width: CGFloat(cgImage.width),
      height: CGFloat(cgImage.height)
    )
    let fillColor = CGColor(
      srgbRed: whiteChannel,
      green: whiteChannel,
      blue: whiteChannel,
      alpha: opaqueAlpha
    )
    context.setFillColor(fillColor)
    context.fill(bounds)
    context.draw(cgImage, in: bounds)
    return context.makeImage() ?? cgImage
  }

  private static func preferredRGBColorSpace(for cgImage: CGImage) -> CGColorSpace {
    if let space = cgImage.colorSpace, space.model == .rgb {
      return space
    }
    return CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
  }

  private static func makeOpaqueRGBContext(
    width: Int,
    height: Int,
    colorSpace: CGColorSpace
  ) -> CGContext? {
    let bitmapInfo =
      CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue
    return CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: bitsPerComponent,
      bytesPerRow: automaticBytesPerRow,
      space: colorSpace,
      bitmapInfo: bitmapInfo
    )
  }
}
