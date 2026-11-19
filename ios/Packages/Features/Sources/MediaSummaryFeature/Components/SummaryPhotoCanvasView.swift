import CoreGraphics
import Dependencies
import DesignSystem
import Domain
import MediaStorage
import SwiftUI

struct SummaryPhotoCanvasView: View {
  let page: MediaSummaryPageState
  let authorColorHex: String
  let isMarkerPlacementMode: Bool
  let onSelectMarker: (Int) -> Void
  let onDeselectAll: () -> Void
  let onAddMarker: (Double, Double) -> Void

  @State private var previewImage: CGImage?
  @Dependency(\.mediaStorage) private var mediaStorage

  private var photoAspectRatio: CGFloat {
    guard page.draft.width > 0, page.draft.height > 0 else {
      return MediaSummaryConstants.fallbackPhotoAspectRatio
    }
    return CGFloat(page.draft.width) / CGFloat(page.draft.height)
  }

  var body: some View {
    ZStack {
      if let previewImage {
        Image(decorative: previewImage, scale: MediaSummaryConstants.imageRenderScale)
          .resizable()
          .scaledToFit()
      } else {
        Rectangle()
          .fill(.secondary.opacity(MediaSummaryConstants.placeholderBackgroundOpacity))
          .overlay {
            Image(systemName: "photo")
              .font(.title2)
              .foregroundStyle(.secondary)
          }
      }
    }
    .aspectRatio(photoAspectRatio, contentMode: .fit)
    .overlay {
      MarkerDotOverlayView(
        markers: page.markerOverlayItems(authorColorHex: authorColorHex),
        selectedMarkerNumber: page.selectedMarkerNumber,
        onSelectMarker: onSelectMarker,
        onDeselectAll: onDeselectAll,
        onAddMarkerAtNormalizedPoint: isMarkerPlacementMode ? onAddMarker : nil
      )
    }
    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .task(id: page.draft.id) {
      await loadPreview()
    }
  }

  private func loadPreview() async {
    let mediaId = page.draft.id
    let storage = mediaStorage
    let decoded = await Task.detached(priority: .userInitiated) {
      try? storage.loadDownsampledThumbnail(mediaId, MediaSummaryConstants.previewMaxPixelSize)
    }.value
    guard !Task.isCancelled else {
      return
    }
    previewImage = decoded
  }
}
