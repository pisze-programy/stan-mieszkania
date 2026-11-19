import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

public struct MediaSummaryView: View {
  @Bindable private var store: StoreOf<MediaSummaryFeature>

  public init(store: StoreOf<MediaSummaryFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.md) {
          retakeHeaderBar

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
            descriptionSection(for: page)
          }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
      }

      SummaryActionBarView(
        isSaving: store.isSaving,
        showsCaptureAnother: store.showsCaptureAnotherAction,
        onSaveLocal: { store.send(.saveTapped(mode: .localOnly, captureAnother: false)) },
        onSaveCloud: { store.send(.saveTapped(mode: .cloud, captureAnother: false)) },
        onSaveAndCaptureNext: { store.send(.saveTapped(mode: .cloud, captureAnother: true)) }
      )
    }
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button(L10n.string("apartments.create.cancel.cta")) {
          store.send(.cancelTapped)
        }
        .disabled(store.isSaving)
      }
    }
  }

  private var retakeHeaderBar: some View {
    HStack {
      Button {
        store.send(.retakeTapped)
      } label: {
        Label(L10n.string("capture.retake.cta"), systemImage: "arrow.counterclockwise")
          .font(Typography.callout.weight(.medium))
      }
      .buttonStyle(.glass)
      .disabled(store.isSaving)

      Spacer()

      if store.isMultiPhoto {
        pagerControls
      }
    }
  }

  private var pagerControls: some View {
    HStack(spacing: Spacing.xs) {
      Button {
        store.send(.pageSelected(store.selectedIndex - 1))
      } label: {
        Image(systemName: "chevron.left")
      }
      .disabled(store.selectedIndex <= 0)

      Text("\(store.selectedIndex + 1)/\(store.pages.count)")
        .font(Typography.badge)
        .monospacedDigit()

      Button {
        store.send(.pageSelected(store.selectedIndex + 1))
      } label: {
        Image(systemName: "chevron.right")
      }
      .disabled(store.selectedIndex >= store.pages.count - 1)
    }
    .padding(.horizontal, Spacing.xs)
    .padding(.vertical, Spacing.xxs)
    .glassEffect(.regular, in: .capsule)
  }

  @ViewBuilder
  private var photoPagerSection: some View {
    #if os(iOS)
      TabView(
        selection: Binding(
          get: { store.selectedIndex },
          set: { store.send(.pageSelected($0)) }
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

  private func descriptionSection(for page: MediaSummaryPageState) -> some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      TextField(
        L10n.string("media.summary.description.placeholder"),
        text: Binding(
          get: { page.description },
          set: { store.send(.descriptionChanged($0)) }
        ),
        axis: .vertical
      )
      .lineLimit(
        MediaSummaryConstants
          .descriptionLineRangeMin...MediaSummaryConstants.descriptionLineRangeMax
      )
      .padding(Spacing.sm)
      .glassEffect(.regular, in: .rect(cornerRadius: CornerRadius.md))

      if !page.description.isEmpty && !page.markers.isEmpty {
        GlassCard(cornerRadius: CornerRadius.md, padding: Spacing.sm) {
          HighlightedEntryTextView(
            text: page.description,
            selectedMarkerNumber: page.selectedMarkerNumber,
            authorColorHex: store.currentUser.color
          )
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
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
