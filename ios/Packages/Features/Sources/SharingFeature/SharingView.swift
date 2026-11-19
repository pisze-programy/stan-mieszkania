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
    sharingList
      .refreshable {
        await store.send(.refreshed).finish()
      }
      .task {
        await store.send(.task).finish()
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
      .navigationTitle(L10n.string("sharing.screen.title"))
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(role: .close) {
            store.send(.closeTapped)
          }
        }
      }
  }

  private var sharingList: some View {
    List {
      if store.shouldSuggestInviteCodeReset && store.isOwner {
        securityAlertSection
      }

      inviteCodeSection

      Section(L10n.string("sharing.members.header")) {
        ForEach(store.activeMembers) { member in
          activeMemberRow(member)
        }
      }

      if !store.departedMembers.isEmpty {
        Section(L10n.string("sharing.members.departed.header")) {
          ForEach(store.departedMembers) { member in
            SharingMemberRowView(member: member, isRevoking: false)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    #if os(iOS)
      .listStyle(.insetGrouped)
    #endif
  }

  private var securityAlertSection: some View {
    Section {
      VStack(alignment: .leading, spacing: Spacing.xs) {
        HStack(alignment: .top, spacing: Spacing.sm) {
          Image(systemName: "shield.lefthalf.filled.badge.checkmark")
            .foregroundStyle(.orange)
          Text(L10n.string("sharing.security.banner"))
            .font(Typography.callout)
        }

        Button(L10n.string("sharing.security.reset.cta")) {
          store.send(.resetCodeTapped)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.accentColor)
        .disabled(store.isResettingCode)
      }
      .padding(.vertical, Spacing.xxs)
    }
  }

  private var inviteCodeSection: some View {
    Section(L10n.string("sharing.code.label")) {
      InviteCodeCardView(
        inviteCode: store.inviteCode,
        shareMessageText: store.shareMessageText,
        showCopiedFeedback: store.showCopiedFeedback,
        onCopyTapped: { store.send(.copyCodeTapped) }
      )

      if store.isOwner {
        resetCodeRow
      }
    }
  }

  private var resetCodeRow: some View {
    Button {
      store.send(.resetCodeTapped)
    } label: {
      HStack(spacing: Spacing.xs) {
        if store.isResettingCode {
          ProgressView()
            .controlSize(.small)
        } else {
          Image(systemName: "arrow.clockwise")
        }
        Text(L10n.string("sharing.code.reset.cta"))
      }
      .font(.subheadline)
      .foregroundStyle(.secondary)
    }
    .disabled(store.isResettingCode)
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
  }

  @ViewBuilder
  private func activeMemberRow(_ member: ApartmentMember) -> some View {
    let canRevoke = store.isOwner && member.role == .contributor && member.isActive
    let row = SharingMemberRowView(
      member: member,
      isRevoking: store.revokingUserId == member.userId
    )
    .confirmationDialog(
      L10n.string("sharing.member.revoke.confirm.title"),
      isPresented: Binding(
        get: { store.pendingRevokeMember?.id == member.id },
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

    if canRevoke {
      row
        .swipeActions(edge: .trailing) {
          Button(L10n.string("sharing.member.revoke.cta"), role: .destructive) {
            store.send(.revokeMemberTapped(member))
          }
        }
        .contextMenu {
          Button(role: .destructive) {
            store.send(.revokeMemberTapped(member))
          } label: {
            Label(
              L10n.string("sharing.member.revoke.cta"),
              systemImage: "person.badge.minus"
            )
          }
        }
    } else {
      row
    }
  }
}
