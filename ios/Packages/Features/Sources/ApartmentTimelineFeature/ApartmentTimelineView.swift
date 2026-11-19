import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

public struct ApartmentTimelineView: View {
  @Bindable var store: StoreOf<ApartmentTimelineFeature>
  @State var isQuotaPopoverPresented = false
  private let zoomNamespace: Namespace.ID?

  private var gridColumns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(), spacing: Spacing.xs),
      count: ApartmentTimelineConstants.gridColumnCount
    )
  }

  private var activeToastKey: String? {
    store.errorMessage ?? store.quotaNoticeMessage
  }

  public init(
    store: StoreOf<ApartmentTimelineFeature>,
    zoomNamespace: Namespace.ID? = nil
  ) {
    self.store = store
    self.zoomNamespace = zoomNamespace
  }

  public var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: Spacing.md, pinnedViews: [.sectionHeaders]) {
        if !store.hasLoadedLocalSnapshot {
          Color.clear
            .frame(height: ApartmentTimelineConstants.loadingPlaceholderHeight)
        } else if store.sections.isEmpty {
          emptyStateView
        } else {
          ForEach(store.sections) { section in
            Section {
              LazyVGrid(columns: gridColumns, spacing: Spacing.xs) {
                ForEach(section.items) { item in
                  thumbnailButton(for: item)
                }
              }
            } header: {
              TimelineDayHeaderView(title: section.title)
            }
          }
        }
      }
      .padding(.horizontal, Spacing.md)
      .padding(.vertical, Spacing.sm)
    }
    .appCanvas()
    .refreshable {
      await store.send(.pulledToRefresh).finish()
    }
    .task {
      await store.send(.task).finish()
    }
    .overlay(alignment: .top) {
      toastOverlay
    }
    .animation(Motion.smooth, value: activeToastKey)
    .overlay(alignment: .bottomTrailing) {
      TimelineCaptureMenuButtonView(isDisabled: store.isCaptureInProgress) { source in
        store.send(.captureSourceSelected(source))
      }
      .padding(Spacing.lg)
    }
    .navigationTitle(store.navigationTitle)
    .toolbar {
      timelineToolbar
    }
    .sheet(
      item: Binding(
        get: { store.editSheet },
        set: { if $0 == nil { store.send(.editSheetDismissed) } }
      )
    ) { sheet in
      EditApartmentSheetView(store: store, sheet: sheet)
    }
    .sheet(
      item: Binding(
        get: { store.historySheet },
        set: { if $0 == nil { store.send(.historySheetDismissed) } }
      )
    ) { sheet in
      ApartmentHistorySheetView(
        sheet: sheet,
        referenceDate: store.now ?? Date()
      )
    }
    .confirmationSheet(
      isPresented: Binding(
        get: { store.leaveConfirmationMode != nil },
        set: { if !$0 { store.send(.leaveConfirmationDismissed) } }
      ),
      isConfirming: store.isLeavingOrDeleting,
      onDismiss: { store.send(.leaveConfirmationDidDismiss) },
      content: { store.leaveOrDeleteConfirmationContent },
      onConfirm: { store.send(.leaveOrDeleteConfirmed) }
    )
  }

  @ViewBuilder
  private var toastOverlay: some View {
    if let errorMessage = store.errorMessage {
      ToastBanner(message: errorMessage, style: .error) {
        store.send(.dismissError)
      }
      .padding(.horizontal, Spacing.md)
      .padding(.top, Spacing.xs)
      .transition(.move(edge: .top).combined(with: .opacity))
    } else if let quotaNotice = store.quotaNoticeMessage {
      ToastBanner(message: quotaNotice, style: .info) {
        store.send(.dismissQuotaNotice)
      }
      .padding(.horizontal, Spacing.md)
      .padding(.top, Spacing.xs)
      .transition(.move(edge: .top).combined(with: .opacity))
    }
  }

  private func thumbnailButton(for item: TimelineMediaItem) -> some View {
    Button {
      store.send(.mediaTapped(item.id))
    } label: {
      TimelineThumbnailCellView(
        item: item,
        uploadProgress: store.uploadProgressByMediaId[item.id],
        showsAuthor: store.showsAuthor
      )
    }
    .buttonStyle(.plain)
    .modifier(
      OptionalZoomTransitionSourceModifier(
        sourceID: "\(ApartmentTimelineConstants.zoomTransitionSourcePrefix)\(item.id)",
        namespace: zoomNamespace
      )
    )
  }

  private var emptyStateView: some View {
    ContentUnavailableView(
      L10n.string("apartment.timeline.empty.title"),
      systemImage: "photo.on.rectangle.angled",
      description: Text(L10n.string("apartment.timeline.empty.subtitle"))
    )
    .padding(.top, Spacing.xxl)
  }
}
