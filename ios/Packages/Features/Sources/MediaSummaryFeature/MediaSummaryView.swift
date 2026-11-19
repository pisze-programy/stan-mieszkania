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
      VStack(alignment: .leading, spacing: Spacing.sm) {
        photoPagerSection

        if let page = store.currentPage {
          Text(L10n.string("media.marker.instruction"))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

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
      ToolbarItem(placement: .confirmationAction) {
        Button(role: .confirm) {
          isDescriptionFocused = false
          store.send(.saveButtonTapped)
        }
        .disabled(store.isSaving)
        .accessibilityLabel(L10n.string("media.summary.save.a11y"))
      }
    }
    .sheet(
      isPresented: Binding(
        get: { store.isSaveSheetPresented },
        set: { if !$0 { store.send(.saveSheetDismissed) } }
      ),
      onDismiss: { store.send(.saveSheetDidDismiss) },
      content: {
        SummarySaveSheetView(
          savingMode: store.savingMode,
          errorMessage: store.saveErrorMessage,
          onSelect: { store.send(.saveTapped(mode: $0)) }
        )
        .interactiveDismissDisabled(store.isSaving)
      }
    )
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
      onSelectMarker: { store.send(.markerSelected($0)) },
      onAddMarker: { x, y in store.send(.markerAddedAt(x: x, y: y)) },
      onRemoveMarker: { store.send(.markerRemoveRequested($0)) }
    )
  }
}
