import Domain
import SwiftUI
import Testing

@testable import DesignSystem

@Suite("DesignSystem Components Tests")
struct ComponentsTests {
  private enum Fixtures {
    static let markerId = "01933e2a-7b40-7000-8000-000000000001"
    static let authorColor = "#007AFF"
    static let containerWidth: CGFloat = 200
    static let containerHeight: CGFloat = 100
    static let halfNormalized = 0.5
    static let quarterNormalized = 0.25
    static let outOfBoundsLow = -0.4
    static let outOfBoundsHigh = 1.8
    static let tapX: CGFloat = 50
    static let tapY: CGFloat = 75
    static let expectedTapNormalizedX = 0.25
    static let expectedTapNormalizedY = 0.75
    static let uploadProgress = 0.6
  }

  @Test("Builds AttributedString highlighting selected marker token and its clause")
  func highlightedEntryTextBuildsAttributedString() {
    let text = "[1] Rysa na szybie. [2] Klamka luźna."
    let highlightColor = AuthorPalette.color(fromHex: Fixtures.authorColor)

    let attributed = HighlightedEntryTextBuilder.buildAttributedString(
      text: text,
      selectedMarkerNumber: 1,
      highlightColor: highlightColor
    )
    #expect(String(attributed.characters) == text)

    let highlightedRuns = attributed.runs.filter { $0.backgroundColor != nil }
    let highlightedText = highlightedRuns.map { String(attributed[$0.range].characters) }.joined()
    #expect(highlightedText == "[1] Rysa na szybie. ")

    let trailingText = "Rysa na drzwiach [1]"
    let trailingAttributed = HighlightedEntryTextBuilder.buildAttributedString(
      text: trailingText,
      selectedMarkerNumber: 1,
      highlightColor: highlightColor
    )
    let trailingHighlighted = trailingAttributed.runs
      .filter { $0.backgroundColor != nil }
      .map { String(trailingAttributed[$0.range].characters) }
      .joined()
    #expect(trailingHighlighted == trailingText)

    let unselected = HighlightedEntryTextBuilder.buildAttributedString(
      text: text,
      selectedMarkerNumber: nil,
      highlightColor: highlightColor
    )
    #expect(unselected.runs.allSatisfy { $0.backgroundColor == nil })
  }

  @Test("Clamps marker coordinates to 0...1 and maps points to container size")
  func markerOverlayCoordinateMapping() {
    #expect(MarkerOverlayItem.clampedNormalizedCoordinate(Fixtures.outOfBoundsLow) == 0)
    #expect(MarkerOverlayItem.clampedNormalizedCoordinate(Fixtures.outOfBoundsHigh) == 1)

    let item = MarkerOverlayItem(
      id: Fixtures.markerId,
      number: 1,
      x: Fixtures.outOfBoundsHigh,
      y: Fixtures.halfNormalized,
      authorColorHex: Fixtures.authorColor
    )
    let size = CGSize(width: Fixtures.containerWidth, height: Fixtures.containerHeight)
    let mapped = MarkerOverlayItem.pointInContainer(item, size: size)
    #expect(
      mapped
        == CGPoint(
          x: Fixtures.containerWidth, y: Fixtures.containerHeight * Fixtures.halfNormalized))

    let (nx, ny) = MarkerOverlayItem.normalizedPoint(
      for: CGPoint(x: Fixtures.tapX, y: Fixtures.tapY),
      in: size
    )
    #expect(nx == Fixtures.expectedTapNormalizedX)
    #expect(ny == Fixtures.expectedTapNormalizedY)

    let zeroMapped = MarkerOverlayItem.normalizedPoint(
      for: CGPoint(x: Fixtures.tapX, y: Fixtures.tapY),
      in: .zero
    )
    #expect(zeroMapped == (0, 0))
  }

  @MainActor
  @Test("Instantiates all Liquid Glass and badge components cleanly")
  func instantiatesAllComponents() {
    let card = GlassCard { Text("Karta") }
    let primaryButton = GlassActionButton(title: "Do chmury", systemImage: "icloud.and.arrow.up") {}
    let secondaryButton = GlassActionButton(title: "Lokalnie", variant: .secondary) {}
    let fab = GlassFloatingActionButton(accessibilityLabel: "Dodaj zdjęcie") {}
    let verified = VerifiedBadgeView(style: .labeled)
    let uploading = SyncStatusIndicatorView(
      syncState: .uploading,
      isVerified: false,
      uploadProgress: Fixtures.uploadProgress,
      compact: false
    )
    let sourceBadge = MediaSourceBadgeView(source: .imported, capturedAtFromImport: true)
    let avatar = AuthorAvatarView(
      displayName: "Jan Kowalski",
      colorHex: Fixtures.authorColor,
      role: .owner,
      showsRoleBadge: true
    )
    let markerItem = MarkerOverlayItem(
      id: Fixtures.markerId,
      number: 1,
      x: Fixtures.quarterNormalized,
      y: Fixtures.halfNormalized,
      authorColorHex: Fixtures.authorColor
    )
    let overlay = MarkerDotOverlayView(
      markers: [markerItem],
      selectedMarkerNumber: 1,
      onSelectMarker: { _ in },
      onDeselectAll: {},
      onAddMarkerAtNormalizedPoint: { _, _ in }
    )
    let entryText = HighlightedEntryTextView(
      text: "[1] Rysa",
      selectedMarkerNumber: 1,
      authorColorHex: Fixtures.authorColor
    )

    _ = (
      card,
      primaryButton,
      secondaryButton,
      fab,
      verified,
      uploading,
      sourceBadge,
      avatar,
      overlay,
      entryText,
    )
  }
}
