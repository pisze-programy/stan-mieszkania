import CoreGraphics
import Dependencies
import DesignSystem
import Domain
import MediaStorage
import SwiftUI

struct MediaLightboxView: View {
  let mediaId: String
  let placeholderImage: CGImage?
  let markers: [MarkerOverlayItem]
  let selectedMarkerNumber: Int?
  let selectedCaption: LightboxMarkerCaption?
  let areMarkersHidden: Bool
  let referenceDate: Date
  let onSelectMarker: (Int) -> Void
  let onClearSelection: () -> Void
  let onToggleMarkers: () -> Void
  let onDismiss: () -> Void

  @State private var fullResImage: CGImage?
  @State private var zoomTransform: ZoomTransform = .identity
  @State private var dragOffsetY: CGFloat = 0
  @Dependency(\.mediaStorage) private var mediaStorage

  private var displayedImage: CGImage? {
    fullResImage ?? placeholderImage
  }

  private var isAtRestZoom: Bool {
    zoomTransform.scale <= 1 + MediaDetailConstants.lightboxZoomTolerance
  }

  private var backdropOpacity: Double {
    let progress = min(abs(dragOffsetY) / MediaDetailConstants.lightboxDismissFadeDistance, 1)
    return max(1 - Double(progress), MediaDetailConstants.lightboxMinBackdropOpacity)
  }

  var body: some View {
    ZStack {
      Color.black.opacity(backdropOpacity).ignoresSafeArea()
      photoContent.offset(y: dragOffsetY)
      if !areMarkersHidden {
        markerOverlay.offset(y: dragOffsetY).transition(.opacity)
      }
      chromeOverlay.zIndex(MediaDetailConstants.lightboxChromeZIndex)
    }
    .animation(Motion.fade, value: areMarkersHidden)
    .animation(Motion.snappy, value: selectedMarkerNumber)
    .simultaneousGesture(dismissDragGesture)
    .task(id: mediaId) { await loadFullResolutionImage() }
    #if os(iOS)
      .statusBarHidden(true)
      .persistentSystemOverlays(.hidden)
    #endif
  }

  @ViewBuilder
  private var photoContent: some View {
    if let displayedImage {
      ZoomableScrollView(
        image: displayedImage,
        transform: $zoomTransform,
        onSingleTap: onClearSelection
      )
      .ignoresSafeArea()
    } else {
      ProgressView().tint(.white)
    }
  }

  @ViewBuilder
  private var markerOverlay: some View {
    let imageRect = zoomTransform.imageFrameInViewport
    if imageRect.width > 0, imageRect.height > 0 {
      ZStack(alignment: .topLeading) {
        Color.clear.allowsHitTesting(false)
        ForEach(markers) { marker in
          let isSelected = selectedMarkerNumber == marker.number
          MarkerPinBadgeView(
            marker: marker,
            isSelected: isSelected,
            isDimmed: selectedMarkerNumber != nil && !isSelected,
            onTap: { onSelectMarker(marker.number) }
          )
          .allowsHitTesting(true)
          .position(MarkerOverlayItem.pointInRect(marker, rect: imageRect))
        }
      }
      .ignoresSafeArea()
      .allowsHitTesting(!areMarkersHidden)
    }
  }

  private var chromeOverlay: some View {
    VStack {
      HStack {
        GlassIconButton(
          systemImage: "xmark",
          accessibilityLabel: L10n.string("common.close"),
          action: onDismiss
        )

        Spacer()

        if !markers.isEmpty {
          GlassIconButton(
            systemImage: areMarkersHidden ? "eye.slash" : "eye",
            accessibilityLabel: L10n.string(
              areMarkersHidden ? "media.markers.show" : "media.markers.hide"
            ),
            action: onToggleMarkers
          )
        }
      }
      .padding(.horizontal, Spacing.md)
      .safeAreaPadding(.top, Spacing.xs)

      Spacer()

      if let selectedCaption, !areMarkersHidden {
        MediaLightboxCaptionCard(
          caption: selectedCaption,
          referenceDate: referenceDate,
          onSelectMarker: onSelectMarker
        )
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.md)
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
  }

  private var dismissDragGesture: some Gesture {
    DragGesture(minimumDistance: MediaDetailConstants.lightboxDragMinimumDistance)
      .onChanged { value in
        guard isAtRestZoom, abs(value.translation.height) > abs(value.translation.width) else {
          return
        }
        dragOffsetY = value.translation.height
      }
      .onEnded { value in
        guard isAtRestZoom else {
          dragOffsetY = 0
          return
        }
        let passedDistance =
          abs(value.translation.height) > MediaDetailConstants.lightboxDismissTranslation
        let passedVelocity =
          abs(value.predictedEndTranslation.height) > MediaDetailConstants.lightboxDismissPredicted
        if passedDistance || passedVelocity {
          onDismiss()
        } else {
          withAnimation(Motion.smooth) { dragOffsetY = 0 }
        }
      }
  }

  private func loadFullResolutionImage() async {
    let targetId = mediaId
    let storage = mediaStorage
    let decoded = await Task.detached(priority: .userInitiated) {
      try? storage.loadDownsampledThumbnail(targetId, MediaDetailConstants.lightboxMaxPixelSize)
    }.value
    guard !Task.isCancelled, let decoded else { return }
    fullResImage = decoded
  }
}
