import ComposableArchitecture
import DesignSystem
import SwiftUI

extension ApartmentTimelineView {
  @ToolbarContentBuilder
  var timelineToolbar: some ToolbarContent {
    ToolbarItem(placement: .automatic) {
      cloudStatusItem
    }

    if store.isOwner {
      ToolbarItem(placement: .automatic) {
        Button {
          store.send(.shareTapped)
        } label: {
          Image(
            systemName: store.shouldHighlightShare
              ? "person.badge.key.fill"
              : "person.2"
          )
          .foregroundStyle(store.shouldHighlightShare ? Color.orange : Color.primary)
          .padding(Spacing.xxs)
          .background(
            store.shouldHighlightShare
              ? Color.orange.opacity(ApartmentTimelineConstants.shareHighlightOpacity)
              : Color.clear,
            in: .circle
          )
        }
        .accessibilityLabel(L10n.string("sharing.screen.title"))
      }
    }

    ToolbarItem(placement: .automatic) {
      moreMenu
    }
  }

  @ViewBuilder
  private var cloudStatusItem: some View {
    if store.localUnsyncedCount > 0 {
      Button {
        store.send(.syncAllLocalTapped)
      } label: {
        Label("\(store.localUnsyncedCount)", systemImage: "icloud.and.arrow.up")
          .font(.footnote.weight(.semibold))
          .monospacedDigit()
          .contentTransition(.numericText())
          .foregroundStyle(Color.accentColor)
          .symbolEffect(.pulse, isActive: store.isSyncingAllLocal)
          .frame(minWidth: ApartmentTimelineConstants.cloudStatusMinWidth)
      }
      .disabled(store.isSyncingAllLocal)
      .accessibilityLabel(L10n.format("apartment.timeline.sync.all", store.localUnsyncedCount))
    } else {
      Button {
        isQuotaPopoverPresented = true
      } label: {
        Label(
          L10n.format(
            "apartment.timeline.quota.badge",
            store.cloudMediaCount,
            store.quotaLimit
          ),
          systemImage: "icloud"
        )
        .font(.footnote.weight(.semibold))
        .monospacedDigit()
        .contentTransition(.numericText())
        .lineLimit(ApartmentTimelineConstants.quotaBadgeLineLimit)
        .frame(minWidth: ApartmentTimelineConstants.cloudStatusMinWidth)
      }
      .popover(isPresented: $isQuotaPopoverPresented) {
        Text(
          L10n.format(
            "apartment.timeline.quota.popover",
            store.cloudMediaCount,
            store.quotaLimit
          )
        )
        .font(Typography.callout)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: ApartmentTimelineConstants.quotaPopoverMaxWidth)
        .padding(Spacing.md)
        .presentationCompactAdaptation(.popover)
      }
    }
  }

  private var moreMenu: some View {
    Menu {
      if store.isOwner {
        Button {
          store.send(.editMenuTapped)
        } label: {
          Label(L10n.string("apartment.edit.sheet.title"), systemImage: "pencil")
        }
      }

      Button {
        store.send(.historyMenuTapped)
      } label: {
        Label(L10n.string("apartment.history.sheet.title"), systemImage: "clock.arrow.circlepath")
      }

      Button(role: .destructive) {
        store.send(.leaveOrDeleteMenuTapped)
      } label: {
        Label(
          store.isOwner
            ? L10n.string("apartment.delete.confirmation.title")
            : L10n.string("apartment.leave.confirmation.title"),
          systemImage: store.isOwner ? "trash" : "rectangle.portrait.and.arrow.right"
        )
      }
    } label: {
      Image(systemName: "ellipsis")
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

  var leaveDialogTitle: String {
    switch store.leaveConfirmationMode {
    case .ownerDeleteOrLeave:
      L10n.string("apartment.delete.confirmation.title")
    case .contributorLeave, .none:
      L10n.string("apartment.leave.confirmation.title")
    }
  }

  var leaveDialogMessage: String {
    switch store.leaveConfirmationMode {
    case .ownerDeleteOrLeave:
      if store.hasOtherMembers {
        return L10n.string("apartment.delete.confirmation.message.transfer")
      }
      return L10n.string("apartment.delete.confirmation.message")
    case .contributorLeave, .none:
      return L10n.string("apartment.leave.confirmation.message")
    }
  }

  var leaveDialogConfirmLabel: String {
    switch store.leaveConfirmationMode {
    case .ownerDeleteOrLeave:
      L10n.string("apartment.delete.confirm.cta")
    case .contributorLeave, .none:
      L10n.string("apartment.leave.confirm.cta")
    }
  }
}

struct OptionalZoomTransitionSourceModifier: ViewModifier {
  let sourceID: String
  let namespace: Namespace.ID?

  // Decision S2-13: Attach matchedTransitionSource when parent provides a zoom namespace.
  func body(content: Content) -> some View {
    if let namespace {
      content.matchedTransitionSource(id: sourceID, in: namespace)
    } else {
      content
    }
  }
}
