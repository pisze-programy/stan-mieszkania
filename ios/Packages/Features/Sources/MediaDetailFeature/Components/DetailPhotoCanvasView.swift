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
  let isComposerPlacementActive: Bool
  let onSelectMarker: (Int) -> Void
  let onDeselectAll: () -> Void
  let onAddComposerMarker: (Double, Double) -> Void

  @State private var photoImage: CGImage?
  @Dependency(\.mediaStorage) private var mediaStorage

  private var aspectRatio: CGFloat {
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
    .aspectRatio(aspectRatio, contentMode: .fit)
    .frame(maxWidth: .infinity, maxHeight: MediaDetailConstants.photoMaxHeight)
    .overlay {
      if !media.isSoftDeleted {
        MarkerDotOverlayView(
          markers: markers,
          selectedMarkerNumber: selectedMarkerNumber,
          onSelectMarker: onSelectMarker,
          onDeselectAll: onDeselectAll,
          onAddMarkerAtNormalizedPoint: isComposerPlacementActive ? onAddComposerMarker : nil
        )
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
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
    if let photoImage {
      Image(decorative: photoImage, scale: MediaDetailConstants.imageRenderScale)
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
    photoImage = decoded
  }
}
