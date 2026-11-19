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
  var toastOverlay: some View {
    VStack(spacing: Spacing.xs) {
      if let quotaNotice = store.quotaNoticeMessage {
        ToastBanner(message: quotaNotice, style: .info) {
          store.send(.dismissQuotaNotice)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
      }
      if let errorMessage = store.errorMessage {
        ToastBanner(message: errorMessage, style: .error) {
          store.send(.dismissError)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .padding(.horizontal, Spacing.md)
    .padding(.top, Spacing.xs)
  }

  func statusAndSyncBar(for media: MediaItem) -> some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      HStack(spacing: Spacing.sm) {
        SyncStatusIndicatorView(
          syncState: media.syncState,
          isVerified: media.isVerified,
          uploadProgress: store.uploadProgress,
          placement: .labeled,
          onVerifiedTap: { verifiedInfoSubject = .photo },
          onLocalOnlyTap: { isLocalInfoPresented = true }
        )
        Spacer()
        if media.source == .imported {
          MediaSourceBadgeView(
            source: media.source,
            capturedAtFromImport: media.capturedAtFromImport
          )
        }
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

  @ViewBuilder
  var entriesSection: some View {
    if !store.entries.isEmpty {
      VStack(alignment: .leading, spacing: Spacing.sm) {
        Text(L10n.string("media.detail.entries.header"))
          .font(.headline)

        ForEach(store.entries) { item in
          DetailEntryRowView(
            item: item,
            referenceDate: store.now ?? Date(),
            selectedMarkerNumber: store.selectedMarkerNumber,
            canEditOrHardDelete: store.state.canEditOrHardDeleteEntry(item),
            canRetract: store.state.canRetractEntry(item),
            onMarkerTapped: { store.send(.markerTapped($0)) },
            onVerifiedTap: { verifiedInfoSubject = .entry },
            onEditLocal: { store.send(.editLocalEntryTapped(item.id)) },
            onDeleteOrRetract: { store.send(.entryDeleteTapped(item.id)) }
          )
          .id(item.id)
        }
      }
    }
  }

  var mediaDeleteConfirmationContent: ConfirmationSheetContent {
    if store.mediaDeleteConfirmation == .hardDeleteLocal {
      return ConfirmationSheetContent(
        systemImage: "trash",
        title: L10n.string("media.detail.delete.local.title"),
        message: L10n.string("media.detail.delete.local.message"),
        confirmTitle: L10n.string("media.detail.delete.cta"),
        tone: .destructive
      )
    }
    return ConfirmationSheetContent(
      systemImage: "trash",
      title: L10n.string("media.detail.delete.cloud.title"),
      message: L10n.string("media.detail.delete.synced.message"),
      confirmTitle: L10n.string("media.detail.delete.cta"),
      tone: .destructive
    )
  }

  var entryDeleteConfirmationContent: ConfirmationSheetContent {
    if case .hardDeleteLocal = store.entryDeleteConfirmation {
      return ConfirmationSheetContent(
        systemImage: "trash",
        title: L10n.string("media.detail.entry.delete.local.title"),
        message: L10n.string("media.detail.entry.delete.local.message"),
        confirmTitle: L10n.string("media.detail.entry.delete.cta"),
        tone: .destructive
      )
    }
    return ConfirmationSheetContent(
      systemImage: "arrow.uturn.backward",
      title: L10n.string("media.detail.entry.retract.confirm.title"),
      message: L10n.string("media.detail.entry.retract.confirm.message"),
      confirmTitle: L10n.string("media.detail.entry.retract.cta"),
      tone: .destructive
    )
  }
}
