import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

public struct MediaSummaryView: View {
  @Bindable private var store: StoreOf<MediaSummaryFeature>
  @FocusState private var isDescriptionFocused: Bool

  public init(store: StoreOf<MediaSummaryFeature>) {
    self.store = store
  }

  private var navigationTitle: String {
    store.isMultiPhoto
      ? L10n.summaryMultiTitle(store.pages.count)
      : L10n.string("media.summary.title.single")
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Spacing.md) {
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
            isInteractive: !store.isSaving,
            isFocused: $isDescriptionFocused,
            onDescriptionChanged: { store.send(.descriptionChanged($0)) }
          )
        }
      }
      .padding(.horizontal, Spacing.md)
      .padding(.vertical, Spacing.sm)
    }
    .appCanvas()
    .safeAreaInset(edge: .bottom) {
      SummaryActionBarView(
        savingMode: store.savingMode,
        onSaveLocal: { triggerSave(mode: .localOnly) },
        onSaveCloud: { triggerSave(mode: .cloud) }
      )
    }
    .overlay(alignment: .top) {
      if let errorMessage = store.errorMessage {
        ToastBanner(message: errorMessage, style: .error) {
          store.send(.dismissError)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.xs)
        .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .animation(Motion.smooth, value: store.errorMessage)
    .task {
      await store.send(.task).finish()
    }
    .onDisappear {
      isDescriptionFocused = false
    }
    .navigationTitle(navigationTitle)
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button(role: .cancel) {
          isDescriptionFocused = false
          store.send(.cancelTapped)
        }
        .disabled(store.isSaving)
      }
    }
  }

  private func triggerSave(mode: MediaSummarySaveMode) {
    isDescriptionFocused = false
    store.send(.saveTapped(mode: mode))
  }

  @ViewBuilder
  private var photoPagerSection: some View {
    let basePager = Group {
      #if os(iOS)
        TabView(
          selection: Binding(
            get: { store.selectedIndex },
            set: { newIndex in
              guard !store.isSaving, newIndex != store.selectedIndex else {
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
      #else
        if let page = store.currentPage {
          canvas(for: page)
        }
      #endif
    }

    basePager
      .containerRelativeFrame(.vertical) { containerHeight, _ in
        min(
          containerHeight * MediaSummaryConstants.photoHeightRatio,
          MediaSummaryConstants.photoMaxHeightCap
        )
      }
      .overlay(alignment: .bottom) {
        if store.isMultiPhoto {
          SummaryPagerCapsuleView(
            selectedIndex: store.selectedIndex,
            pageCount: store.pages.count,
            onSelectPage: { store.send(.pageSelected($0)) }
          )
          .padding(.bottom, Spacing.sm)
        }
      }
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
    let formattedDate = PolishDateFormatters.formatHumanTimestamp(
      page.draft.capturedAt,
      now: store.now ?? Date()
    )
    return HStack(spacing: Spacing.sm) {
      Label(formattedDate, systemImage: "clock")
        .font(.footnote)
        .foregroundStyle(.secondary)
      Spacer()
      if page.draft.source == .imported {
        MediaSourceBadgeView(
          source: page.draft.source,
          capturedAtFromImport: page.draft.capturedAtFromImport
        )
      }
    }
  }
}
