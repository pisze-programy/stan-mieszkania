import CoreGraphics
import Dependencies
import DesignSystem
import Domain
import MediaStorage
import SwiftUI

struct DetailPhotoCanvasView: View {
  private struct PhotoLoadKey: Equatable {
    let mediaId: String
    let isPhotoCached: Bool
    let isSoftDeleted: Bool
  }

  let media: MediaItem
  let isPhotoCached: Bool
  let markers: [MarkerOverlayItem]
  let selectedMarkerNumber: Int?
  let areMarkersHidden: Bool
  let isComposerPlacementActive: Bool
  let photoMaxHeight: CGFloat
  let lightboxSourceID: String
  let lightboxNamespace: Namespace.ID
  @Binding var decodedImage: CGImage?
  let onSelectMarker: (Int) -> Void
  let onPhotoTapped: () -> Void
  let onToggleMarkers: () -> Void
  let onAddComposerMarker: (Double, Double) -> Void
  let onRemoveComposerMarker: (Int) -> Void

  @Dependency(\.mediaStorage) private var mediaStorage

  private var displayAspectRatio: CGFloat {
    if let decodedImage, decodedImage.width > 0, decodedImage.height > 0 {
      return CGFloat(decodedImage.width) / CGFloat(decodedImage.height)
    }
    guard media.width > 0, media.height > 0 else {
      return MediaDetailConstants.fallbackPhotoAspectRatio
    }
    return CGFloat(media.width) / CGFloat(media.height)
  }

  var body: some View {
    ZStack {
      if media.isSoftDeleted {
        tombstoneView
      } else {
        activePhotoView
      }
    }
    .aspectRatio(displayAspectRatio, contentMode: .fit)
    .onTapGesture {
      if !media.isSoftDeleted {
        onPhotoTapped()
      }
    }
    .overlay {
      if !media.isSoftDeleted {
        MarkerDotOverlayView(
          markers: markers,
          selectedMarkerNumber: selectedMarkerNumber,
          onSelectMarker: onSelectMarker,
          onDeselectAll: nil,
          onAddMarkerAtNormalizedPoint: isComposerPlacementActive ? onAddComposerMarker : nil,
          onRemoveMarker: isComposerPlacementActive ? onRemoveComposerMarker : nil
        )
        .opacity(areMarkersHidden ? 0 : 1)
        .allowsHitTesting(!areMarkersHidden)
        .animation(Motion.fade, value: areMarkersHidden)
      }
    }
    .clipShape(.rect(cornerRadius: CornerRadius.photo, style: .continuous))
    .overlay(alignment: .bottomTrailing) {
      if !media.isSoftDeleted, !markers.isEmpty, !isComposerPlacementActive {
        GlassIconButton(
          systemImage: areMarkersHidden ? "eye.slash" : "eye",
          accessibilityLabel: L10n.string(
            areMarkersHidden ? "media.markers.show" : "media.markers.hide"
          ),
          size: MediaDetailConstants.eyeToggleSize,
          action: onToggleMarkers
        )
        .padding(MediaDetailConstants.eyeTogglePadding)
      }
    }
    .matchedTransitionSource(id: lightboxSourceID, in: lightboxNamespace)
    .frame(maxWidth: .infinity, maxHeight: photoMaxHeight)
    .task(
      id: PhotoLoadKey(
        mediaId: media.id,
        isPhotoCached: isPhotoCached,
        isSoftDeleted: media.isSoftDeleted
      )
    ) {
      await loadPhoto()
    }
  }

  @ViewBuilder
  private var activePhotoView: some View {
    if let decodedImage {
      Image(decorative: decodedImage, scale: MediaDetailConstants.imageRenderScale)
        .resizable()
        .scaledToFit()
    } else {
      Rectangle()
        .fill(.secondary.opacity(MediaDetailConstants.placeholderBackgroundOpacity))
        .overlay {
          ProgressView()
        }
    }
  }

  private var tombstoneView: some View {
    Rectangle()
      .fill(.secondary.opacity(MediaDetailConstants.tombstoneBackgroundOpacity))
      .overlay {
        VStack(spacing: Spacing.xs) {
          Image(systemName: "trash")
            .font(.title2)
            .foregroundStyle(.secondary)
          Text(L10n.string("apartment.timeline.photo.tombstone"))
            .font(Typography.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(Spacing.md)
      }
      .opacity(DesignMetrics.tombstoneOpacity)
  }

  private func loadPhoto() async {
    guard !media.isSoftDeleted else {
      return
    }
    let mediaId = media.id
    let storage = mediaStorage
    let decoded = await Task.detached(priority: .userInitiated) {
      try? storage.loadDownsampledThumbnail(mediaId, MediaDetailConstants.photoMaxPixelSize)
    }.value
    guard !Task.isCancelled else {
      return
    }
    decodedImage = decoded
  }
}
