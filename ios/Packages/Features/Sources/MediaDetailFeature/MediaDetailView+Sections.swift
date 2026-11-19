import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

extension MediaDetailView {
  @ToolbarContentBuilder
  var detailToolbar: some ToolbarContent {
    ToolbarItem(placement: .automatic) {
      Button {
        store.send(.metadataTapped)
      } label: {
        Image(systemName: "info.circle")
      }
      .accessibilityLabel(L10n.string("media.detail.metadata.title"))
    }

    if store.canDeleteMedia {
      ToolbarItem(placement: .automatic) {
        Button(role: .destructive) {
          store.send(.mediaDeleteTapped)
        } label: {
          Image(systemName: "trash")
        }
        .accessibilityLabel(L10n.string("apartment.delete.confirm.cta"))
      }
    }
  }

  @ViewBuilder
  var bannersSection: some View {
    if let quotaNotice = store.quotaNoticeMessage {
      banner(message: quotaNotice, icon: "icloud.slash.fill", tint: .orange) {
        store.send(.dismissQuotaNotice)
      }
    }
    if let errorMessage = store.errorMessage {
      banner(message: errorMessage, icon: "exclamationmark.triangle.fill", tint: .yellow) {
        store.send(.dismissError)
      }
    }
  }

  func statusAndSyncBar(for media: MediaItem) -> some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      HStack(spacing: Spacing.sm) {
        SyncStatusIndicatorView(
          syncState: media.syncState,
          isVerified: media.isVerified,
          uploadProgress: store.uploadProgress,
          compact: false
        )
        Spacer()
        MediaSourceBadgeView(
          source: media.source,
          capturedAtFromImport: media.capturedAtFromImport
        )
      }

      if store.canUploadToCloud {
        GlassActionButton(
          title: L10n.string("media.detail.upload.cta"),
          systemImage: "icloud.and.arrow.up",
          variant: .primary,
          isLoading: store.isUploadingToCloud
        ) {
          store.send(.uploadToCloudTapped)
        }
      }
    }
  }

  var entriesSection: some View {
    VStack(alignment: .leading, spacing: Spacing.sm) {
      Text(L10n.string("media.detail.timeline.title"))
        .font(Typography.sectionHeader)

      if store.entries.isEmpty {
        Text(L10n.string("media.detail.timeline.empty"))
          .font(Typography.callout)
          .foregroundStyle(.secondary)
      } else {
        ForEach(store.entries) { item in
          DetailEntryRowView(
            item: item,
            selectedMarkerNumber: store.selectedMarkerNumber,
            canEditOrHardDelete: store.state.canEditOrHardDeleteEntry(item),
            canRetract: store.state.canRetractEntry(item),
            onEditLocal: { store.send(.editLocalEntryTapped(item.id)) },
            onDeleteOrRetract: { store.send(.entryDeleteTapped(item.id)) }
          )
          .id(item.id)
        }
      }
    }
  }

  private func banner(
    message: String,
    icon: String,
    tint: Color,
    onDismiss: @escaping () -> Void
  ) -> some View {
    GlassCard(cornerRadius: CornerRadius.md, padding: Spacing.sm) {
      HStack(spacing: Spacing.sm) {
        Image(systemName: icon).foregroundStyle(tint)
        Text(message).font(Typography.callout).frame(maxWidth: .infinity, alignment: .leading)
        Button(action: onDismiss) { Image(systemName: "xmark") }.buttonStyle(.plain)
      }
    }
  }

  var mediaDeleteTitle: String {
    store.mediaDeleteConfirmation == .hardDeleteLocal
      ? L10n.string("media.detail.delete.local.title")
      : L10n.string("media.detail.delete.cloud.title")
  }

  var entryDeleteTitle: String {
    if case .hardDeleteLocal = store.entryDeleteConfirmation {
      return L10n.string("media.detail.entry.delete.local.title")
    }
    return L10n.string("media.detail.entry.retract.confirm.title")
  }

  var entryDeleteConfirmLabel: String {
    if case .retractSynced = store.entryDeleteConfirmation {
      return L10n.string("media.detail.entry.retract.cta")
    }
    return L10n.string("apartment.delete.confirm.cta")
  }
}
