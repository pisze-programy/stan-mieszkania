import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

public struct ApartmentsListView: View {
  @Bindable private var store: StoreOf<ApartmentsListFeature>

  public init(store: StoreOf<ApartmentsListFeature>) {
    self.store = store
  }

  public var body: some View {
    ScrollView {
      VStack(spacing: Spacing.md) {
        if store.items.isEmpty && !store.isSyncing {
          emptyStateView
        } else {
          LazyVStack(spacing: Spacing.sm) {
            ForEach(store.items) { item in
              Button {
                store.send(.apartmentTapped(item.id))
              } label: {
                ApartmentCardView(item: item)
              }
              .buttonStyle(PressableCardButtonStyle())
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
    .onDisappear {
      store.send(.viewDisappeared)
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
    .overlay(alignment: .bottomTrailing) {
      addMenuButton
        .padding(Spacing.lg)
    }
    .navigationTitle(L10n.string("apartments.list.title"))
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button {
          store.send(.profileTapped)
        } label: {
          AuthorAvatarView(
            displayName: store.currentUser?.displayName
              ?? DomainConstants.fallbackUserDisplayPrefix,
            colorHex: store.currentUser?.color ?? DomainConstants.defaultAuthorColor,
            size: DesignMetrics.avatarSmallSize
          )
        }
        .accessibilityLabel(L10n.string("profile.screen.title"))
      }
    }
    .sheet(
      item: Binding(
        get: { store.createSheet },
        set: { if $0 == nil { store.send(.createSheetDismissed) } }
      )
    ) { sheet in
      CreateApartmentSheetView(store: store, sheet: sheet)
    }
    .sheet(
      item: Binding(
        get: { store.joinSheet },
        set: { if $0 == nil { store.send(.joinSheetDismissed) } }
      )
    ) { sheet in
      JoinApartmentSheetView(store: store, sheet: sheet)
    }
  }

  private var addMenuButton: some View {
    Menu {
      Button {
        store.send(.createMenuTapped)
      } label: {
        Label(L10n.string("apartments.create.sheet.title"), systemImage: "plus.circle")
      }
      Button {
        store.send(.joinMenuTapped)
      } label: {
        Label(L10n.string("apartments.join.sheet.title"), systemImage: "person.badge.key")
      }
    } label: {
      Image(systemName: "plus")
        .font(.title2.weight(.semibold))
        .frame(
          width: DesignMetrics.floatingActionButtonSize,
          height: DesignMetrics.floatingActionButtonSize
        )
        .contentShape(.circle)
        .glassEffect(.regular.interactive(), in: .circle)
    }
    .accessibilityLabel(L10n.string("apartments.create.sheet.title"))
  }

  private var emptyStateView: some View {
    ContentUnavailableView(
      L10n.string("apartments.list.empty.title"),
      systemImage: "building.2",
      description: Text(L10n.string("apartments.list.empty.subtitle"))
    )
    .padding(.top, Spacing.xxl)
  }
}

extension ApartmentsListFeature.CreateApartmentSheetState: Identifiable {
  public var id: String { "create" }
}

extension ApartmentsListFeature.JoinApartmentSheetState: Identifiable {
  public var id: String { "join" }
}
