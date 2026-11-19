import CoreGraphics
import SwiftUI
import Testing

@testable import DesignSystem

@Suite("HighlightedEntryTextView Color Rendering Tests")
struct HighlightedEntryTextColorTests {
  private struct LinkRun {
    let text: String
    let url: URL
    let hasBackground: Bool
  }

  private enum RenderMetrics {
    static let renderScale: CGFloat = 2
    static let padding: CGFloat = 8
    static let bytesPerPixel = 4
    static let bitsPerComponent = 8
    static let channelDominanceThreshold = 50
    static let alphaThreshold = 100
    static let halfDivisor = 2
    static let markerTwoNumber = 2
  }

  @Test("Builder styles only linked tokens and leaves unlinked [n] and plain text unstyled")
  func highlightedEntryTextStylesOnlyTokens() {
    let text = "[1] Rysa na szybie. [2] Klamka luźna. [99]"
    let linked: Set<Int> = [1, RenderMetrics.markerTwoNumber]
    let selected = HighlightedEntryTextBuilder.buildAttributedString(
      text: text,
      selectedMarkerNumber: 1,
      linkedMarkerNumbers: linked
    )
    #expect(String(selected.characters) == text)

    let plainRuns = selected.runs.filter { $0.link == nil }
    #expect(!plainRuns.isEmpty)
    #expect(plainRuns.allSatisfy { $0.foregroundColor == nil && $0.backgroundColor == nil })
    let plainCombined = plainRuns.map { String(selected[$0.range].characters) }.joined()
    #expect(plainCombined.contains("[99]"))

    let linkRuns = selected.runs.compactMap { run -> LinkRun? in
      guard let link = run.link else { return nil }
      return LinkRun(
        text: String(selected[run.range].characters),
        url: link,
        hasBackground: run.backgroundColor != nil
      )
    }
    #expect(linkRuns.count == RenderMetrics.markerTwoNumber)
    #expect(linkRuns[0].text == "[1]")
    #expect(linkRuns[0].url == URL(string: "marker://1"))
    #expect(linkRuns[0].hasBackground)
    #expect(linkRuns[1].text == "[2]")
    #expect(linkRuns[1].url == URL(string: "marker://2"))
    #expect(!linkRuns[1].hasBackground)

    let unselected = HighlightedEntryTextBuilder.buildAttributedString(
      text: text,
      selectedMarkerNumber: nil,
      linkedMarkerNumbers: linked
    )
    #expect(unselected.runs.allSatisfy { $0.backgroundColor == nil })
    let parsedNumber = HighlightedEntryTextBuilder.markerNumber(from: linkRuns[1].url)
    #expect(parsedNumber == RenderMetrics.markerTwoNumber)
  }

  @MainActor
  @Test("Renders [1] token in red and [2] token in blue without tint override")
  func rendersPerMarkerTokenColors() throws {
    let view = HighlightedEntryTextView(
      text: "[1] test [2]",
      selectedMarkerNumber: nil,
      linkedMarkerNumbers: [1, RenderMetrics.markerTwoNumber],
      onMarkerTapped: { _ in }
    )
    .padding(RenderMetrics.padding)
    .background(.white)

    let renderer = ImageRenderer(content: view)
    renderer.scale = RenderMetrics.renderScale
    let image = try #require(renderer.cgImage)

    let pixels = try rgbaPixels(from: image)
    let midpoint = image.width / RenderMetrics.halfDivisor
    var leftRedDominantCount = 0
    var rightBlueDominantCount = 0

    for y in 0..<image.height {
      for x in 0..<image.width {
        let offset = (y * image.width + x) * RenderMetrics.bytesPerPixel
        let red = Int(pixels[offset])
        let blue = Int(pixels[offset + 2])
        let alpha = Int(pixels[offset + 3])
        guard alpha > RenderMetrics.alphaThreshold else {
          continue
        }
        if x < midpoint, red - blue > RenderMetrics.channelDominanceThreshold {
          leftRedDominantCount += 1
        }
        if x >= midpoint, blue - red > RenderMetrics.channelDominanceThreshold {
          rightBlueDominantCount += 1
        }
      }
    }

    #expect(leftRedDominantCount > 0)
    #expect(rightBlueDominantCount > 0)
  }

  private func rgbaPixels(from image: CGImage) throws -> [UInt8] {
    let bytesPerRow = image.width * RenderMetrics.bytesPerPixel
    var buffer = [UInt8](repeating: 0, count: bytesPerRow * image.height)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    let context = try #require(
      CGContext(
        data: &buffer,
        width: image.width,
        height: image.height,
        bitsPerComponent: RenderMetrics.bitsPerComponent,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo
      )
    )
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return buffer
  }
}
