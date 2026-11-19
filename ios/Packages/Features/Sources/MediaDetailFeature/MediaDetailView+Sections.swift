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
        .confirmationDialog(
          mediaDeleteTitle,
          isPresented: Binding(
            get: { store.mediaDeleteConfirmation != nil },
            set: { if !$0 { store.send(.mediaDeleteConfirmationDismissed) } }
          ),
          titleVisibility: .visible
        ) {
          Button(L10n.string("apartment.delete.confirm.cta"), role: .destructive) {
            store.send(.mediaDeleteConfirmed)
          }
          Button(L10n.string("apartments.create.cancel.cta"), role: .cancel) {
            store.send(.mediaDeleteConfirmationDismissed)
          }
        }
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
          onVerifiedTap: { isVerifiedInfoPresented = true },
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
          let isConfirming = store.entryDeleteConfirmation?.entryId == item.id
          DetailEntryRowView(
            item: item,
            referenceDate: store.now ?? Date(),
            selectedMarkerNumber: store.selectedMarkerNumber,
            hasOtherMembers: store.hasOtherMembers,
            canEditOrHardDelete: store.state.canEditOrHardDeleteEntry(item),
            canRetract: store.state.canRetractEntry(item),
            isConfirmingDelete: isConfirming,
            deleteConfirmationTitle: entryDeleteTitle,
            deleteConfirmationMessage: entryDeleteMessage,
            deleteConfirmButtonLabel: entryDeleteConfirmLabel,
            onMarkerTapped: { store.send(.markerTapped($0)) },
            onVerifiedTap: { isVerifiedInfoPresented = true },
            onEditLocal: { store.send(.editLocalEntryTapped(item.id)) },
            onDeleteOrRetract: { store.send(.entryDeleteTapped(item.id)) },
            onConfirmDelete: { store.send(.entryDeleteConfirmed) },
            onDismissDelete: { store.send(.entryDeleteConfirmationDismissed) }
          )
          .id(item.id)
        }
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

  var entryDeleteMessage: String? {
    if case .retractSynced = store.entryDeleteConfirmation {
      return L10n.string("media.detail.entry.retract.confirm.message")
    }
    return nil
  }

  var entryDeleteConfirmLabel: String {
    if case .retractSynced = store.entryDeleteConfirmation {
      return L10n.string("media.detail.entry.retract.cta")
    }
    return L10n.string("apartment.delete.confirm.cta")
  }
}
