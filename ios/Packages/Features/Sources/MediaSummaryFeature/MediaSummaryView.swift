import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

public struct MediaSummaryView: View {
  @Bindable private var store: StoreOf<MediaSummaryFeature>
  @FocusState private var isDescriptionFocused: Bool
  @State private var isClosing = false

  public init(store: StoreOf<MediaSummaryFeature>) {
    self.store = store
  }

  private var isDescriptionInteractive: Bool {
    !store.isSaving && !isClosing
  }

  public var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.md) {
          SummaryHeaderBarView(
            isSaving: store.isSaving,
            isMultiPhoto: store.isMultiPhoto,
            selectedIndex: store.selectedIndex,
            pageCount: store.pages.count,
            onRetake: {
              isDescriptionFocused = false
              isClosing = true
              store.send(.retakeTapped)
            },
            onSelectPage: { store.send(.pageSelected($0)) }
          )

          if let errorMessage = store.errorMessage {
            errorBanner(errorMessage)
          }

          photoPagerSection

          if let page = store.currentPage {
            metadataRow(for: page)
            SummaryMarkerControlsView(
              markers: page.markers,
              selectedMarkerNumber: page.selectedMarkerNumber,
              authorColorHex: store.currentUser.color,
              isPlacementMode: store.isMarkerPlacementMode,
              onTogglePlacement: { store.send(.toggleMarkerPlacementMode) },
              onSelectMarker: { store.send(.markerSelected($0)) },
              onDeleteMarker: { store.send(.markerDeleted($0)) }
            )
            SummaryDescriptionSectionView(
              description: page.description,
              markers: page.markers,
              selectedMarkerNumber: page.selectedMarkerNumber,
              authorColorHex: store.currentUser.color,
              isInteractive: isDescriptionInteractive,
              isFocused: $isDescriptionFocused,
              onDescriptionChanged: { store.send(.descriptionChanged($0)) }
            )
          }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
      }

      SummaryActionBarView(
        isSaving: store.isSaving,
        showsCaptureAnother: store.showsCaptureAnotherAction,
        onSaveLocal: { triggerSave(mode: .localOnly, captureAnother: false) },
        onSaveCloud: { triggerSave(mode: .cloud, captureAnother: false) },
        onSaveAndCaptureNext: { triggerSave(mode: .cloud, captureAnother: true) }
      )
    }
    .onChange(of: store.isSaving) { _, isSaving in
      if isSaving {
        isDescriptionFocused = false
        isClosing = true
      }
    }
    .onChange(of: store.errorMessage) { _, errorMessage in
      if errorMessage != nil {
        isClosing = false
      }
    }
    .onDisappear {
      isDescriptionFocused = false
      isClosing = true
    }
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button(L10n.string("apartments.create.cancel.cta")) {
          isDescriptionFocused = false
          isClosing = true
          store.send(.cancelTapped)
        }
        .disabled(store.isSaving)
      }
    }
  }

  private func triggerSave(mode: MediaSummarySaveMode, captureAnother: Bool) {
    isDescriptionFocused = false
    isClosing = true
    store.send(.saveTapped(mode: mode, captureAnother: captureAnother))
    if !store.isSaving {
      isClosing = false
    }
  }

  @ViewBuilder
  private var photoPagerSection: some View {
    #if os(iOS)
      TabView(
        selection: Binding(
          get: { store.selectedIndex },
          set: { newIndex in
            guard isDescriptionInteractive, newIndex != store.selectedIndex else {
              return
            }
            store.send(.pageSelected(newIndex))
          }
        )
      ) {
        ForEach(Array(store.pages.enumerated()), id: \.element.id) { index, page in
          canvas(for: page)
            .tag(index)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .frame(height: MediaSummaryConstants.photoMaxHeight)
    #else
      if let page = store.currentPage {
        canvas(for: page)
          .frame(height: MediaSummaryConstants.photoMaxHeight)
      }
    #endif
  }

  private func canvas(for page: MediaSummaryPageState) -> some View {
    SummaryPhotoCanvasView(
      page: page,
      authorColorHex: store.currentUser.color,
      isMarkerPlacementMode: store.isMarkerPlacementMode,
      onSelectMarker: { store.send(.markerSelected($0)) },
      onDeselectAll: { store.send(.markerSelectionCleared) },
      onAddMarker: { x, y in store.send(.markerAddedAt(x: x, y: y)) }
    )
  }

  private func metadataRow(for page: MediaSummaryPageState) -> some View {
    let formattedDate = PolishDateFormatters.formatTimestamp(page.draft.capturedAt)
    return HStack(spacing: Spacing.sm) {
      Text(L10n.format("media.summary.timestamp.label", formattedDate))
        .font(Typography.footnote)
        .foregroundStyle(.secondary)
      Spacer()
      MediaSourceBadgeView(
        source: page.draft.source,
        capturedAtFromImport: page.draft.capturedAtFromImport
      )
    }
  }

  private func errorBanner(_ message: String) -> some View {
    GlassCard(cornerRadius: CornerRadius.md, padding: Spacing.sm) {
      HStack(spacing: Spacing.sm) {
        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
        Text(message).font(Typography.callout).frame(maxWidth: .infinity, alignment: .leading)
        Button {
          store.send(.dismissError)
        } label: {
          Image(systemName: "xmark")
        }
        .buttonStyle(.plain)
      }
    }
  }
}
