import Domain
import SwiftUI
import Testing

@testable import DesignSystem

@Suite("DesignSystem Components Tests")
struct ComponentsTests {
  private enum Fixtures {
    static let markerId = "01933e2a-7b40-7000-8000-000000000001"
    static let authorColor = "#007AFF"
    static let markerOneColor = "#FF3B30"
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
    static let paletteWrapNumber = 9
    static let paletteSecondWrapNumber = 10
    static let paletteSecondIndex = 2
    static let aspectFourByThree: CGFloat = 4.0 / 3.0
    static let expectedFittedWidth: CGFloat = 400.0 / 3.0
  }

  @Test("Clamps marker coordinates to 0...1 and maps points to container and aspect-fit rects")
  func markerOverlayCoordinateMapping() {
    #expect(MarkerOverlayItem.clampedNormalizedCoordinate(Fixtures.outOfBoundsLow) == 0)
    #expect(MarkerOverlayItem.clampedNormalizedCoordinate(Fixtures.outOfBoundsHigh) == 1)

    let item = MarkerOverlayItem(
      id: Fixtures.markerId,
      number: 1,
      x: Fixtures.outOfBoundsHigh,
      y: Fixtures.halfNormalized,
      colorHex: Fixtures.markerOneColor
    )
    let size = CGSize(width: Fixtures.containerWidth, height: Fixtures.containerHeight)
    let mapped = MarkerOverlayItem.pointInContainer(item, size: size)
    #expect(
      mapped
        == CGPoint(
          x: Fixtures.containerWidth, y: Fixtures.containerHeight * Fixtures.halfNormalized))

    let fitted = ZoomTransform.aspectFitRect(aspectRatio: Fixtures.aspectFourByThree, in: size)
    #expect(abs(fitted.width - Fixtures.expectedFittedWidth) < 0.01)
    #expect(abs(fitted.height - Fixtures.containerHeight) < 0.01)

    let (nx, ny) = MarkerOverlayItem.normalizedPoint(
      for: CGPoint(x: Fixtures.tapX, y: Fixtures.tapY),
      in: size
    )
    #expect(nx == Fixtures.expectedTapNormalizedX)
    #expect(ny == Fixtures.expectedTapNormalizedY)
    #expect(
      MarkerOverlayItem.normalizedPoint(for: CGPoint(x: Fixtures.tapX, y: Fixtures.tapY), in: .zero)
        == (0, 0)
    )
  }

  @Test("Cycles MarkerPalette hexes deterministically across marker numbers")
  func markerPaletteCycles() {
    #expect(MarkerPalette.hex(forMarkerNumber: 0) == MarkerPalette.hexes[0])
    #expect(MarkerPalette.hex(forMarkerNumber: 1) == MarkerPalette.hexes[0])
    #expect(
      MarkerPalette.hex(forMarkerNumber: Fixtures.paletteWrapNumber) == MarkerPalette.hexes[0]
    )
    #expect(
      MarkerPalette.hex(forMarkerNumber: Fixtures.paletteSecondWrapNumber)
        == MarkerPalette.hex(forMarkerNumber: Fixtures.paletteSecondIndex)
    )
  }

  @MainActor
  @Test("VerifiedBadgeView renders seal, inline, and labeled styles without V glyph")
  func verifiedBadgeHasNoCompactVLabel() {
    let seal = VerifiedBadgeView(style: .seal)
    let inline = VerifiedBadgeView(style: .inline)
    let labeled = VerifiedBadgeView(style: .labeled, onTap: {})

    for badge in [seal, inline, labeled] {
      let mirrorValues = Mirror(reflecting: badge).children.map { String(describing: $0.value) }
      #expect(!mirrorValues.contains("V"))
    }
    #expect(!L10n.string("media.detail.status.verified").isEmpty)
    #expect(!L10n.string("verified.info.title").isEmpty)
  }

  @MainActor
  @Test("GlassActionButton preserves intrinsic width when loading toggles with or without subtitle")
  func glassActionButtonPreservesWidthWhileLoading() throws {
    let idleButton = GlassActionButton(
      title: "Chmura",
      subtitle: "Zweryfikowane, widoczne dla wszystkich",
      systemImage: "icloud.and.arrow.up",
      isLoading: false,
      expandsHorizontally: false
    ) {}
    let loadingButton = GlassActionButton(
      title: "Chmura",
      subtitle: "Zweryfikowane, widoczne dla wszystkich",
      systemImage: "icloud.and.arrow.up",
      isLoading: true,
      expandsHorizontally: false
    ) {}

    let idleImage = try #require(ImageRenderer(content: idleButton).cgImage)
    let loadingImage = try #require(ImageRenderer(content: loadingButton).cgImage)
    #expect(idleImage.width == loadingImage.width)
    #expect(idleImage.height == loadingImage.height)
  }

  @MainActor
  @Test("Instantiates SurfaceCard, badges, ToastBanner, StableSlot, and VerifiedInfoSheetView")
  func instantiatesAllComponents() {
    let card = SurfaceCard { Text("Karta") }
    let fab = GlassFloatingActionButton(accessibilityLabel: "Dodaj zdjęcie") {}
    let iconButton = GlassIconButton(systemImage: "xmark", accessibilityLabel: "Zamknij") {}
    let photoInfoSheet = VerifiedInfoSheetView(subject: .photo)
    let entryInfoSheet = VerifiedInfoSheetView(subject: .entry)
    let stableSlot = StableSlot { Text("Skopiowano") }
    let toast = ToastBanner(message: "Błąd sieci", style: .error, onDismiss: {})
    let uploading = SyncStatusIndicatorView(
      syncState: .uploading, isVerified: false,
      uploadProgress: Fixtures.uploadProgress, placement: .labeled
    )
    let local = SyncStatusIndicatorView(
      syncState: .localOnly, isVerified: false, placement: .labeled, onLocalOnlyTap: {}
    )
    let sourceBadge = MediaSourceBadgeView(source: .imported, capturedAtFromImport: true)
    let avatar = AuthorAvatarView(
      displayName: "Jan Kowalski", colorHex: Fixtures.authorColor,
      role: .owner, showsRoleBadge: false
    )
    let markerItem = MarkerOverlayItem(
      id: Fixtures.markerId, number: 1,
      x: Fixtures.quarterNormalized, y: Fixtures.halfNormalized,
      colorHex: Fixtures.markerOneColor
    )
    let overlay = MarkerDotOverlayView(
      markers: [markerItem], selectedMarkerNumber: 1,
      onSelectMarker: { _ in }, onDeselectAll: {},
      onAddMarkerAtNormalizedPoint: { _, _ in }, onRemoveMarker: { _ in }
    )
    let entryText = HighlightedEntryTextView(
      text: "[1] Rysa", selectedMarkerNumber: 1, linkedMarkerNumbers: [1], onMarkerTapped: { _ in }
    )

    _ = (
      card, fab, iconButton, photoInfoSheet, entryInfoSheet, stableSlot, toast, uploading, local,
      sourceBadge, avatar, overlay, entryText,
    )
  }
}
