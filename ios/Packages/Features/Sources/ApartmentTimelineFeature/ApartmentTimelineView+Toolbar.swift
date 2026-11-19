import ComposableArchitecture
import DesignSystem
import SwiftUI

extension ApartmentTimelineView {
  @ToolbarContentBuilder
  var timelineToolbar: some ToolbarContent {
    ToolbarItem(placement: .automatic) {
      quotaPill
    }

    if store.localUnsyncedCount > 0 {
      ToolbarItem(placement: .automatic) {
        Button {
          store.send(.syncAllLocalTapped)
        } label: {
          if store.isSyncingAllLocal {
            ProgressView()
              .controlSize(.small)
          } else {
            Text(L10n.format("apartment.timeline.sync.all", store.localUnsyncedCount))
              .font(Typography.badge)
              .monospacedDigit()
              .contentTransition(.numericText())
          }
        }
        .disabled(store.isSyncingAllLocal)
      }
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
        Image(systemName: "ellipsis.circle")
      }
    }
  }

  private var quotaPill: some View {
    Text(
      L10n.format(
        "apartment.timeline.quota.badge",
        store.cloudMediaCount,
        store.quotaLimit
      )
    )
    .font(Typography.badge)
    .monospacedDigit()
    .contentTransition(.numericText())
    .lineLimit(ApartmentTimelineConstants.quotaBadgeLineLimit)
    .padding(.horizontal, Spacing.xs)
    .padding(.vertical, Spacing.xxs)
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
      L10n.string("apartment.delete.confirmation.message")
    case .contributorLeave, .none:
      L10n.string("apartment.leave.confirmation.message")
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
