import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

public struct MediaDetailView: View {
  @Bindable var store: StoreOf<MediaDetailFeature>
  @State var isVerifiedInfoPresented = false

  public init(store: StoreOf<MediaDetailFeature>) {
    self.store = store
  }

  public var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.md) {
          bannersSection

          if let media = store.media {
            DetailPhotoCanvasView(
              media: media,
              isPhotoCached: store.isPhotoCached,
              markers: store.overlayMarkers,
              selectedMarkerNumber: store.selectedMarkerNumber,
              isComposerPlacementActive: store.composer?.isMarkerPlacementMode == true,
              onSelectMarker: { store.send(.markerTapped($0)) },
              onDeselectAll: { store.send(.markerSelectionCleared) },
              onAddComposerMarker: { x, y in store.send(.composerMarkerAdded(x: x, y: y)) }
            )

            statusAndSyncBar(for: media)
          }

          composerSection
          entriesSection
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
      }
      .appCanvas()
      .onChange(of: store.scrollTargetEntryId) { _, targetId in
        guard let targetId else {
          return
        }
        withAnimation(Motion.snappy) {
          proxy.scrollTo(targetId, anchor: .center)
        }
        store.send(.scrollTargetHandled)
      }
    }
    .task {
      await store.send(.task).finish()
    }
    .toolbar {
      detailToolbar
    }
    .sheet(
      isPresented: Binding(
        get: { store.isMetadataSheetPresented },
        set: { if !$0 { store.send(.metadataDismissed) } }
      )
    ) {
      if let media = store.media {
        DetailMetadataSheetView(media: media) {
          store.send(.metadataDismissed)
        }
        .presentationDetents([.medium])
      }
    }
    .sheet(isPresented: $isVerifiedInfoPresented) {
      VerifiedInfoSheetView()
    }
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
    .confirmationDialog(
      entryDeleteTitle,
      isPresented: Binding(
        get: { store.entryDeleteConfirmation != nil },
        set: { if !$0 { store.send(.entryDeleteConfirmationDismissed) } }
      ),
      titleVisibility: .visible
    ) {
      Button(entryDeleteConfirmLabel, role: .destructive) {
        store.send(.entryDeleteConfirmed)
      }
      Button(L10n.string("apartments.create.cancel.cta"), role: .cancel) {
        store.send(.entryDeleteConfirmationDismissed)
      }
    }
  }

  @ViewBuilder
  private var composerSection: some View {
    if let composer = store.composer {
      DetailEntryComposerView(
        composer: composer,
        authorColorHex: store.currentUser?.color ?? DomainConstants.defaultAuthorColor,
        selectedMarkerNumber: store.selectedMarkerNumber,
        onTextChanged: { store.send(.composerTextChanged($0)) },
        onToggleMarkerMode: { store.send(.composerToggleMarkerMode) },
        onSelectMarker: { store.send(.markerTapped($0)) },
        onDeleteMarker: { store.send(.composerMarkerDeleted($0)) },
        onSubmit: { store.send(.composerSubmitted) },
        onCancel: { store.send(.composerDismissed) }
      )
    } else if store.canComposeEntry {
      GlassActionButton(
        title: L10n.string("media.detail.entry.add.cta"),
        systemImage: "plus.bubble",
        variant: .secondary
      ) {
        store.send(.addEntryTapped)
      }
    }
  }
}
