import ComposableArchitecture
import CoreGraphics
import DesignSystem
import Domain
import SwiftUI

public struct MediaDetailView: View {
  static let lightboxSourceID = "mediaDetailPhoto"

  @Bindable var store: StoreOf<MediaDetailFeature>
  @State var verifiedInfoSubject: VerifiedInfoSubject?
  @State var isLocalInfoPresented = false
  @State var decodedCanvasImage: CGImage?
  @State private var viewportHeight: CGFloat = 0
  @Namespace private var lightboxNamespace

  public init(store: StoreOf<MediaDetailFeature>) {
    self.store = store
  }

  private var photoMaxHeight: CGFloat {
    guard viewportHeight > 0 else {
      return MediaDetailConstants.defaultPhotoMaxHeight
    }
    return min(
      viewportHeight * MediaDetailConstants.photoMaxHeightRatio,
      MediaDetailConstants.photoMaxHeightCap
    )
  }

  public var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.md) {
          if let media = store.media {
            DetailPhotoCanvasView(
              media: media,
              isPhotoCached: store.isPhotoCached,
              markers: store.overlayMarkers,
              selectedMarkerNumber: store.selectedMarkerNumber,
              areMarkersHidden: store.areMarkersHidden,
              isComposerPlacementActive: store.composer != nil,
              photoMaxHeight: photoMaxHeight,
              lightboxSourceID: Self.lightboxSourceID,
              lightboxNamespace: lightboxNamespace,
              decodedImage: $decodedCanvasImage,
              onSelectMarker: { store.send(.markerTapped($0)) },
              onPhotoTapped: { store.send(.photoTapped) },
              onToggleMarkers: { store.send(.markersVisibilityToggled) },
              onAddComposerMarker: { x, y in store.send(.composerMarkerAdded(x: x, y: y)) },
              onRemoveComposerMarker: { store.send(.composerMarkerRemoveRequested($0)) }
            )

            statusAndSyncBar(for: media)
          }

          composerSection
          entriesSection
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
      }
      .onGeometryChange(for: CGFloat.self) { proxy in
        proxy.size.height
      } action: { height in
        viewportHeight = height
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
    .overlay(alignment: .top) {
      toastOverlay
    }
    .animation(Motion.smooth, value: store.errorMessage)
    .animation(Motion.smooth, value: store.quotaNoticeMessage)
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
        DetailMetadataSheetView(media: media)
      }
    }
    .sheet(item: $verifiedInfoSubject) { subject in
      VerifiedInfoSheetView(subject: subject)
    }
    .sheet(isPresented: $isLocalInfoPresented) {
      LocalOnlyInfoSheetView(
        canUploadToCloud: store.canUploadToCloud,
        isUploadingToCloud: store.isUploadingToCloud,
        onUploadToCloud: {
          isLocalInfoPresented = false
          store.send(.uploadToCloudTapped)
        }
      )
    }
    .confirmationSheet(
      isPresented: Binding(
        get: { store.mediaDeleteConfirmation != nil },
        set: { if !$0 { store.send(.mediaDeleteConfirmationDismissed) } }
      ),
      onDismiss: { store.send(.mediaDeleteSheetDidDismiss) },
      content: { mediaDeleteConfirmationContent },
      onConfirm: { store.send(.mediaDeleteConfirmed) }
    )
    .confirmationSheet(
      isPresented: Binding(
        get: { store.entryDeleteConfirmation != nil },
        set: { if !$0 { store.send(.entryDeleteConfirmationDismissed) } }
      ),
      content: { entryDeleteConfirmationContent },
      onConfirm: { store.send(.entryDeleteConfirmed) }
    )
    #if os(iOS)
      .fullScreenCover(isPresented: lightboxBinding) {
        lightboxView.navigationTransition(
          .zoom(sourceID: Self.lightboxSourceID, in: lightboxNamespace)
        )
      }
    #else
      .sheet(isPresented: lightboxBinding) {
        lightboxView
      }
    #endif
  }

  private var lightboxBinding: Binding<Bool> {
    Binding(
      get: { store.isLightboxPresented },
      set: { if !$0 { store.send(.lightboxDismissed) } }
    )
  }

  private var lightboxView: some View {
    MediaLightboxView(
      mediaId: store.mediaId,
      placeholderImage: decodedCanvasImage,
      markers: store.overlayMarkers,
      selectedMarkerNumber: store.selectedMarkerNumber,
      selectedCaption: store.selectedLightboxCaption,
      areMarkersHidden: store.areMarkersHidden,
      referenceDate: store.now ?? Date(),
      onSelectMarker: { store.send(.markerTapped($0)) },
      onClearSelection: { store.send(.markerSelectionCleared) },
      onToggleMarkers: { store.send(.markersVisibilityToggled) },
      onDismiss: { store.send(.lightboxDismissed) }
    )
  }

  @ViewBuilder
  private var composerSection: some View {
    if let composer = store.composer {
      DetailEntryComposerView(
        composer: composer,
        onTextChanged: { store.send(.composerTextChanged($0)) },
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
