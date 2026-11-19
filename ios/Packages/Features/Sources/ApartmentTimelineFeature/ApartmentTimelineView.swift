import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

public struct ApartmentTimelineView: View {
  @Bindable var store: StoreOf<ApartmentTimelineFeature>
  private let zoomNamespace: Namespace.ID?

  private var gridColumns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(), spacing: Spacing.xs),
      count: ApartmentTimelineConstants.gridColumnCount
    )
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
        if let quotaNotice = store.quotaNoticeMessage {
          noticeBanner(
            message: quotaNotice,
            systemImage: "icloud.slash.fill",
            tint: .orange
          ) {
            store.send(.dismissQuotaNotice)
          }
        }

        if let errorMessage = store.errorMessage {
          noticeBanner(
            message: errorMessage,
            systemImage: "exclamationmark.triangle.fill",
            tint: .yellow
          ) {
            store.send(.dismissError)
          }
        }

        if store.sections.isEmpty && !store.isSyncing {
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
    .refreshable {
      await store.send(.pulledToRefresh).finish()
    }
    .task {
      await store.send(.task).finish()
    }
    .overlay(alignment: .bottomTrailing) {
      GlassFloatingActionButton(
        accessibilityLabel: L10n.string("apartment.timeline.capture.camera")
      ) {
        store.send(.captureButtonTapped)
      }
      .padding(Spacing.lg)
    }
    .navigationTitle(store.navigationTitle)
    .toolbar {
      timelineToolbar
    }
    .sheet(
      isPresented: Binding(
        get: { store.isCaptureSourceSheetPresented },
        set: { if !$0 { store.send(.captureSourceSheetDismissed) } }
      )
    ) {
      CaptureSourceSheetView { source in
        store.send(.captureSourceSelected(source))
      } onCancel: {
        store.send(.captureSourceSheetDismissed)
      }
      .presentationDetents([.medium])
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
      ApartmentHistorySheetView(sheet: sheet) {
        store.send(.historySheetDismissed)
      }
    }
    .confirmationDialog(
      leaveDialogTitle,
      isPresented: Binding(
        get: { store.leaveConfirmationMode != nil },
        set: { if !$0 { store.send(.leaveConfirmationDismissed) } }
      ),
      titleVisibility: .visible
    ) {
      Button(leaveDialogConfirmLabel, role: .destructive) {
        store.send(.leaveOrDeleteConfirmed)
      }
      Button(L10n.string("apartments.create.cancel.cta"), role: .cancel) {
        store.send(.leaveConfirmationDismissed)
      }
    } message: {
      Text(leaveDialogMessage)
    }
  }

  private func thumbnailButton(for item: TimelineMediaItem) -> some View {
    Button {
      store.send(.mediaTapped(item.id))
    } label: {
      TimelineThumbnailCellView(
        item: item,
        uploadProgress: store.uploadProgressByMediaId[item.id]
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

  private func noticeBanner(
    message: String,
    systemImage: String,
    tint: Color,
    onDismiss: @escaping () -> Void
  ) -> some View {
    GlassCard(cornerRadius: CornerRadius.md, padding: Spacing.sm) {
      HStack(spacing: Spacing.sm) {
        Image(systemName: systemImage)
          .foregroundStyle(tint)
        Text(message)
          .font(Typography.callout)
          .frame(maxWidth: .infinity, alignment: .leading)
        Button(action: onDismiss) {
          Image(systemName: "xmark")
        }
        .buttonStyle(.plain)
      }
    }
  }
}
