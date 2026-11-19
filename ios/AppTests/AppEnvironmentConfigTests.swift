import CoreGraphics
import DesignSystem
import Domain
import Foundation
import SwiftUI
import Testing
import UIKit

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

@Suite("iOS 26 Footnote Token Color Verification")
struct FootnoteTokenColorVerificationTests {
  private enum Metrics {
    static let hostWidth: CGFloat = 220
    static let hostHeight: CGFloat = 60
    static let padding: CGFloat = 8
    static let scale: CGFloat = 2
    static let bytesPerPixel = 4
    static let bitsPerComponent = 8
    static let channelDominance = 50
    static let alphaMin = 100
    static let halfDivisor = 2
  }

  @MainActor
  @Test("iOS 26 UIHostingController renders [1] red and [2] blue without tint override")
  func rendersPerMarkerLinkColorsOnIOS26() throws {
    let view = HighlightedEntryTextView(
      text: "[1] test [2]",
      selectedMarkerNumber: nil,
      onMarkerTapped: { _ in }
    )
    .padding(Metrics.padding)
    .background(.white)

    let host = UIHostingController(rootView: view)
    let frame = CGRect(x: 0, y: 0, width: Metrics.hostWidth, height: Metrics.hostHeight)
    let window = UIWindow(frame: frame)
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.frame = frame
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()

    let format = UIGraphicsImageRendererFormat()
    format.scale = Metrics.scale
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: frame.size, format: format)
    let rendered = renderer.image { _ in
      host.view.drawHierarchy(in: frame, afterScreenUpdates: true)
    }
    let cgImage = try #require(rendered.cgImage)
    let (redPixels, bluePixels) = try sampleHalves(in: cgImage)
    #expect(redPixels > 0, "Expected red-dominant pixels for [1] on iOS 26")
    #expect(bluePixels > 0, "Expected blue-dominant pixels for [2] on iOS 26")
  }

  private func sampleHalves(in image: CGImage) throws -> (redLeft: Int, blueRight: Int) {
    let bytesPerRow = image.width * Metrics.bytesPerPixel
    var buffer = [UInt8](repeating: 0, count: bytesPerRow * image.height)
    let context = try #require(
      CGContext(
        data: &buffer,
        width: image.width,
        height: image.height,
        bitsPerComponent: Metrics.bitsPerComponent,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    )
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

    let midpoint = image.width / Metrics.halfDivisor
    var redLeft = 0
    var blueRight = 0
    for y in 0..<image.height {
      for x in 0..<image.width {
        let offset = (y * image.width + x) * Metrics.bytesPerPixel
        let red = Int(buffer[offset])
        let blue = Int(buffer[offset + 2])
        let alpha = Int(buffer[offset + 3])
        guard alpha > Metrics.alphaMin else { continue }
        if x < midpoint, red - blue > Metrics.channelDominance { redLeft += 1 }
        if x >= midpoint, blue - red > Metrics.channelDominance { blueRight += 1 }
      }
    }
    return (redLeft, blueRight)
  }
}
