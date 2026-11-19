import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

public struct SharingView: View {
  @Bindable private var store: StoreOf<SharingFeature>

  public init(store: StoreOf<SharingFeature>) {
    self.store = store
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Spacing.md) {
        if let errorMessage = store.errorMessage {
          errorBanner(errorMessage)
        }

        if store.shouldSuggestInviteCodeReset && store.isOwner {
          securityResetBanner
        }

        InviteCodeCardView(
          inviteCode: store.inviteCode,
          shareMessageText: store.shareMessageText,
          showCopiedFeedback: store.showCopiedFeedback,
          isResettingCode: store.isResettingCode,
          isOwner: store.isOwner,
          onCopyTapped: { store.send(.copyCodeTapped) },
          onResetTapped: { store.send(.resetCodeTapped) }
        )

        membersSection(
          title: L10n.string("sharing.members.header"),
          members: store.activeMembers
        )

        if !store.departedMembers.isEmpty {
          membersSection(
            title: L10n.string("sharing.members.departed.header"),
            members: store.departedMembers
          )
        }
      }
      .padding(Spacing.md)
    }
    .refreshable {
      await store.send(.refreshed).finish()
    }
    .task {
      await store.send(.task).finish()
    }
    .navigationTitle(L10n.string("sharing.screen.title"))
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button(L10n.string("apartment.history.close.cta")) {
          store.send(.closeTapped)
        }
      }
      if store.isLoading {
        ToolbarItem(placement: .automatic) {
          ProgressView()
            .controlSize(.small)
        }
      }
    }
    .confirmationDialog(
      L10n.string("sharing.code.reset.confirm.title"),
      isPresented: Binding(
        get: { store.isResetConfirmationPresented },
        set: { if !$0 { store.send(.resetConfirmationDismissed) } }
      ),
      titleVisibility: .visible
    ) {
      Button(L10n.string("sharing.security.reset.cta"), role: .destructive) {
        store.send(.resetCodeConfirmed)
      }
      Button(L10n.string("apartments.create.cancel.cta"), role: .cancel) {
        store.send(.resetConfirmationDismissed)
      }
    } message: {
      Text(L10n.string("sharing.code.reset.confirm.message"))
    }
    .confirmationDialog(
      L10n.string("sharing.member.revoke.confirm.title"),
      isPresented: Binding(
        get: { store.pendingRevokeMember != nil },
        set: { if !$0 { store.send(.revokeConfirmationDismissed) } }
      ),
      titleVisibility: .visible
    ) {
      Button(L10n.string("sharing.member.revoke.cta"), role: .destructive) {
        store.send(.revokeMemberConfirmed)
      }
      Button(L10n.string("apartments.create.cancel.cta"), role: .cancel) {
        store.send(.revokeConfirmationDismissed)
      }
    } message: {
      Text(L10n.string("sharing.member.revoke.confirm.message"))
    }
  }

  private var securityResetBanner: some View {
    GlassCard(cornerRadius: CornerRadius.md, padding: Spacing.md) {
      VStack(alignment: .leading, spacing: Spacing.sm) {
        HStack(alignment: .top, spacing: Spacing.sm) {
          Image(systemName: "shield.lefthalf.filled.badge.checkmark")
            .foregroundStyle(.orange)
          Text(L10n.string("sharing.security.banner"))
            .font(Typography.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        GlassActionButton(
          title: L10n.string("sharing.security.reset.cta"),
          systemImage: "arrow.clockwise",
          variant: .primary,
          isLoading: store.isResettingCode
        ) {
          store.send(.resetCodeTapped)
        }
      }
    }
  }

  private func membersSection(title: String, members: [ApartmentMember]) -> some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      Text(title)
        .font(Typography.sectionHeader)
        .padding(.horizontal, Spacing.xxs)

      GlassCard(cornerRadius: CornerRadius.lg, padding: Spacing.md) {
        VStack(spacing: Spacing.sm) {
          ForEach(members) { member in
            SharingMemberRowView(
              member: member,
              canRevoke: store.isOwner && member.role == .contributor && member.isActive,
              isRevoking: store.revokingUserId == member.userId,
              onRevokeTapped: { store.send(.revokeMemberTapped(member)) }
            )
            if member.id != members.last?.id {
              Divider()
            }
          }
        }
      }
    }
  }

  private func errorBanner(_ message: String) -> some View {
    GlassCard(cornerRadius: CornerRadius.md, padding: Spacing.sm) {
      HStack(spacing: Spacing.sm) {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.yellow)
        Text(message)
          .font(Typography.callout)
          .frame(maxWidth: .infinity, alignment: .leading)
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
