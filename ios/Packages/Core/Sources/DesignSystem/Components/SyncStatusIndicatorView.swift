import Domain
import SwiftUI

public enum SyncStatusPlacement: Sendable {
  case overPhoto
  case inline
  case labeled
}

public struct SyncStatusIndicatorView: View {
  private static let badgeBackgroundOpacity: Double = 0.16

  private let syncState: MediaSyncState
  private let isVerified: Bool
  private let uploadProgress: Double?
  private let placement: SyncStatusPlacement
  private let onVerifiedTap: (() -> Void)?

  public init(
    syncState: MediaSyncState,
    isVerified: Bool,
    uploadProgress: Double? = nil,
    placement: SyncStatusPlacement = .overPhoto,
    onVerifiedTap: (() -> Void)? = nil
  ) {
    self.syncState = syncState
    self.isVerified = isVerified
    self.uploadProgress = uploadProgress
    self.placement = placement
    self.onVerifiedTap = onVerifiedTap
  }

  @ViewBuilder
  public var body: some View {
    if isVerified || syncState == .verified {
      VerifiedBadgeView(style: verifiedStyle, onTap: onVerifiedTap)
    } else {
      switch syncState {
      case .queued, .uploading:
        uploadingIndicator
      case .localOnly:
        localOnlyIndicator
      case .softDeleted:
        softDeletedIndicator
      case .verified:
        VerifiedBadgeView(style: verifiedStyle, onTap: onVerifiedTap)
      }
    }
  }

  private var verifiedStyle: VerifiedBadgeStyle {
    switch placement {
    case .overPhoto:
      return .seal
    case .inline:
      return .inline
    case .labeled:
      return .labeled
    }
  }

  @ViewBuilder
  private var uploadingIndicator: some View {
    let content = HStack(spacing: Spacing.xxs) {
      if let uploadProgress {
        ProgressView(value: min(max(uploadProgress, 0), 1))
          .progressViewStyle(.circular)
          .frame(
            width: DesignMetrics.progressRingSize,
            height: DesignMetrics.progressRingSize
          )
      } else {
        Image(systemName: "icloud.and.arrow.up")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      if placement == .labeled {
        Text(L10n.string("media.detail.status.uploading"))
          .font(Typography.badge)
      }
    }
    .padding(.horizontal, Spacing.xs)
    .padding(.vertical, Spacing.xxs)

    if placement == .overPhoto {
      content
        .glassEffect(.regular, in: .capsule)
        .accessibilityLabel(L10n.string("media.detail.status.uploading"))
    } else {
      content
        .background(.secondary.opacity(Self.badgeBackgroundOpacity), in: .capsule)
        .accessibilityLabel(L10n.string("media.detail.status.uploading"))
    }
  }

  @ViewBuilder
  private var localOnlyIndicator: some View {
    let content = HStack(spacing: Spacing.xxs) {
      Image(systemName: "icloud.slash")
        .font(Typography.badge)
      if placement == .labeled {
        Text(L10n.string("media.detail.status.local"))
          .font(Typography.badge)
      }
    }
    .foregroundStyle(.secondary)
    .padding(.horizontal, Spacing.xs)
    .padding(.vertical, Spacing.xxs)

    if placement == .overPhoto {
      content
        .glassEffect(.regular, in: .capsule)
        .accessibilityLabel(L10n.string("media.detail.status.local"))
    } else {
      content
        .background(.secondary.opacity(Self.badgeBackgroundOpacity), in: .capsule)
        .accessibilityLabel(L10n.string("media.detail.status.local"))
    }
  }

  private var softDeletedIndicator: some View {
    Image(systemName: "trash")
      .font(Typography.badge)
      .foregroundStyle(.secondary)
      .padding(Spacing.xxs)
      .background(.secondary.opacity(Self.badgeBackgroundOpacity), in: .circle)
      .accessibilityLabel(L10n.string("apartment.timeline.photo.tombstone"))
  }
}
