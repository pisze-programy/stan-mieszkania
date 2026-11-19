import Domain
import SwiftUI

public struct SyncStatusIndicatorView: View {
  private static let badgeBackgroundOpacity: Double = 0.16

  private let syncState: MediaSyncState
  private let isVerified: Bool
  private let uploadProgress: Double?
  private let compact: Bool

  public init(
    syncState: MediaSyncState,
    isVerified: Bool,
    uploadProgress: Double? = nil,
    compact: Bool = true
  ) {
    self.syncState = syncState
    self.isVerified = isVerified
    self.uploadProgress = uploadProgress
    self.compact = compact
  }

  @ViewBuilder
  public var body: some View {
    if isVerified || syncState == .verified {
      VerifiedBadgeView(style: compact ? .compact : .labeled)
    } else {
      switch syncState {
      case .queued, .uploading:
        uploadingIndicator
      case .localOnly:
        localOnlyIndicator
      case .softDeleted:
        softDeletedIndicator
      case .verified:
        VerifiedBadgeView(style: compact ? .compact : .labeled)
      }
    }
  }

  private var uploadingIndicator: some View {
    HStack(spacing: Spacing.xxs) {
      if let uploadProgress {
        ProgressView(value: min(max(uploadProgress, 0), 1))
          .progressViewStyle(.circular)
          .frame(
            width: DesignMetrics.progressRingSize,
            height: DesignMetrics.progressRingSize
          )
      } else {
        ProgressView()
          .controlSize(.small)
      }
      if !compact {
        Text(L10n.string("media.detail.status.uploading"))
          .font(Typography.badge)
      }
    }
    .padding(.horizontal, Spacing.xs)
    .padding(.vertical, Spacing.xxs)
    .glassEffect(.regular, in: .capsule)
    .accessibilityLabel(L10n.string("media.detail.status.uploading"))
  }

  private var localOnlyIndicator: some View {
    HStack(spacing: Spacing.xxs) {
      Image(systemName: "icloud.slash")
        .font(Typography.badge)
      if !compact {
        Text(L10n.string("media.detail.status.local"))
          .font(Typography.badge)
      }
    }
    .foregroundStyle(.secondary)
    .padding(.horizontal, Spacing.xs)
    .padding(.vertical, Spacing.xxs)
    .background(.secondary.opacity(Self.badgeBackgroundOpacity), in: .capsule)
    .accessibilityLabel(L10n.string("media.detail.status.local"))
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
