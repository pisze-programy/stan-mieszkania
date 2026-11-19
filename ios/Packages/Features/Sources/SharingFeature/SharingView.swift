import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

public struct SharingView: View {
  private static let resetIconWidth: CGFloat = 22

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
      .confirmationSheet(
        isPresented: Binding(
          get: { store.pendingRevokeMember != nil },
          set: { if !$0 { store.send(.revokeConfirmationDismissed) } }
        ),
        content: { revokeConfirmationContent },
        onConfirm: { store.send(.revokeMemberConfirmed) }
      )
  }

  private var sharingList: some View {
    List {
      if store.shouldSuggestInviteCodeReset && store.isOwner {
        securityAlertSection
      }

      Section(L10n.string("sharing.code.label")) {
        InviteCodeCardView(
          inviteCode: store.inviteCode,
          shareMessageText: store.shareMessageText,
          showCopiedFeedback: store.showCopiedFeedback,
          showResetFeedback: store.showResetFeedback,
          onCopyTapped: { store.send(.copyCodeTapped) }
        )
        .listRowSeparator(.hidden)
      }

      if store.isOwner {
        Section {
          resetCodeRow
        } footer: {
          Text(L10n.string("sharing.code.reset.footer"))
        }
      }

      Section(L10n.string("sharing.members.header")) {
        if store.sharedWithMembers.isEmpty {
          Label(L10n.string("sharing.members.empty"), systemImage: "person.badge.plus")
            .foregroundStyle(.secondary)
        } else {
          ForEach(store.sharedWithMembers) { member in
            activeMemberRow(member)
          }
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

  private var resetCodeRow: some View {
    Button {
      store.send(.resetCodeTapped)
    } label: {
      HStack(spacing: Spacing.sm) {
        ZStack {
          Image(systemName: "arrow.clockwise")
            .opacity(store.isResettingCode ? 0 : 1)
          if store.isResettingCode {
            ProgressView()
              .controlSize(.small)
          }
        }
        .frame(width: Self.resetIconWidth)

        Text(L10n.string("sharing.code.reset.cta"))
      }
    }
    .disabled(store.isResettingCode)
  }

  @ViewBuilder
  private func activeMemberRow(_ member: ApartmentMember) -> some View {
    let canRevoke = store.isOwner && member.role == .contributor && member.isActive
    let row = SharingMemberRowView(
      member: member,
      isRevoking: store.revokingUserId == member.userId
    )

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

  private var revokeConfirmationContent: ConfirmationSheetContent {
    let memberName =
      store.pendingRevokeMember?.displayName ?? L10n.string("media.detail.user.anonymous")
    return ConfirmationSheetContent(
      systemImage: "person.badge.minus",
      title: L10n.string("sharing.member.revoke.confirm.title"),
      message: L10n.format("sharing.member.revoke.sheet.message", memberName),
      confirmTitle: L10n.string("sharing.member.revoke.cta"),
      tone: .destructive
    )
  }
}
