import CoreGraphics
import Dependencies
import DesignSystem
import Domain
import MediaStorage
import SwiftUI

struct SummaryPhotoCanvasView: View {
  let page: MediaSummaryPageState
  let onSelectMarker: (Int) -> Void
  let onAddMarker: (Double, Double) -> Void
  let onRemoveMarker: (Int) -> Void

  @State private var previewImage: CGImage?
  @Dependency(\.mediaStorage) private var mediaStorage

  private var displayAspectRatio: CGFloat {
    if let previewImage, previewImage.width > 0, previewImage.height > 0 {
      return CGFloat(previewImage.width) / CGFloat(previewImage.height)
    }
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
    .aspectRatio(displayAspectRatio, contentMode: .fit)
    .overlay {
      MarkerDotOverlayView(
        markers: page.markerOverlayItems(),
        selectedMarkerNumber: page.selectedMarkerNumber,
        onSelectMarker: onSelectMarker,
        onDeselectAll: nil,
        onAddMarkerAtNormalizedPoint: onAddMarker,
        onRemoveMarker: onRemoveMarker
      )
    }
    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.photo, style: .continuous))
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
