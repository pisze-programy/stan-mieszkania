import CoreGraphics
import Dependencies
import DesignSystem
import Domain
import MediaStorage
import SwiftUI
import SyncEngine

struct TimelineThumbnailCellView: View {
  private struct ThumbnailTaskKey: Equatable {
    let mediaId: String
    let localFilePath: String?
    let isVerified: Bool
    let isSoftDeleted: Bool
  }

  let item: TimelineMediaItem
  let uploadProgress: Double?
  let showsAuthor: Bool

  @State private var thumbnailImage: CGImage?
  @Dependency(\.syncEngine) private var syncEngine
  @Dependency(\.mediaStorage) private var mediaStorage

  var body: some View {
    ZStack {
      if item.media.isSoftDeleted {
        tombstoneContent
      } else {
        activePhotoContent
      }
    }
    .aspectRatio(DesignMetrics.timelineThumbnailAspectRatio, contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.field, style: .continuous))
    .overlay(alignment: .bottomLeading) {
      if showsAuthor {
        AuthorAvatarView(
          displayName: item.authorDisplayName,
          colorHex: item.authorColorHex,
          size: DesignMetrics.avatarSmallSize
        )
        .padding(Spacing.xxs)
      }
    }
    .overlay(alignment: .topTrailing) {
      if !item.media.isSoftDeleted {
        SyncStatusIndicatorView(
          syncState: item.media.syncState,
          isVerified: item.media.isVerified,
          uploadProgress: uploadProgress,
          placement: .overPhoto
        )
        .padding(Spacing.xxs)
      }
    }
    .task(
      id: ThumbnailTaskKey(
        mediaId: item.media.id,
        localFilePath: item.media.localFilePath,
        isVerified: item.media.isVerified,
        isSoftDeleted: item.media.isSoftDeleted
      )
    ) {
      await loadThumbnailIfNeeded()
    }
  }

  @ViewBuilder
  private var activePhotoContent: some View {
    if let thumbnailImage {
      Image(decorative: thumbnailImage, scale: ApartmentTimelineConstants.imageRenderScale)
        .resizable()
        .scaledToFill()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    } else {
      Rectangle()
        .fill(.secondary.opacity(ApartmentTimelineConstants.placeholderBackgroundOpacity))
        .overlay {
          Image(systemName: "photo")
            .foregroundStyle(.secondary)
        }
    }
  }

  private var tombstoneContent: some View {
    Rectangle()
      .fill(.secondary.opacity(ApartmentTimelineConstants.tombstoneBackgroundOpacity))
      .overlay {
        VStack(spacing: Spacing.xxs) {
          Image(systemName: "trash")
            .font(.callout)
            .foregroundStyle(.secondary)
          Text(L10n.string("apartment.timeline.photo.tombstone"))
            .font(Typography.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineLimit(ApartmentTimelineConstants.tombstoneLineLimit)
            .padding(.horizontal, Spacing.xxs)
        }
      }
      .opacity(DesignMetrics.tombstoneOpacity)
  }

  // Decision S2-10: Lazy cache fetch and downsampled decode per visible timeline cell.
  private func loadThumbnailIfNeeded() async {
    guard !item.media.isSoftDeleted else {
      return
    }
    let mediaId = item.media.id
    if !mediaStorage.fileExists(mediaId), item.media.isVerified {
      _ = try? await syncEngine.ensurePhotoCached(
        item.media.apartmentId,
        mediaId,
        item.media.sha256
      )
    }
    guard !Task.isCancelled else {
      return
    }
    let storage = mediaStorage
    let decoded = await Task.detached(priority: .utility) {
      try? storage.loadDownsampledThumbnail(
        mediaId,
        ApartmentTimelineConstants.thumbnailMaxPixelSize
      )
    }.value
    guard !Task.isCancelled else {
      return
    }
    thumbnailImage = decoded
  }
}
