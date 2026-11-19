import DesignSystem
import Domain
import SwiftUI

struct SharingMemberRowView: View {
  let member: ApartmentMember
  let canRevoke: Bool
  let isRevoking: Bool
  let onRevokeTapped: () -> Void

  var body: some View {
    HStack(spacing: Spacing.sm) {
      AuthorAvatarView(
        displayName: member.displayName,
        colorHex: member.color,
        role: member.role,
        size: DesignMetrics.avatarMediumSize,
        showsRoleBadge: false
      )

      VStack(alignment: .leading, spacing: Spacing.xxs) {
        Text(member.displayName)
          .font(Typography.callout.weight(.semibold))
          .foregroundStyle(.primary)

        Text(roleTitle)
          .font(Typography.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if canRevoke {
        if isRevoking {
          ProgressView()
            .controlSize(.small)
        } else {
          Button(role: .destructive, action: onRevokeTapped) {
            Text(L10n.string("sharing.member.revoke.cta"))
              .font(Typography.caption.weight(.semibold))
          }
          .buttonStyle(.glass)
        }
      }
    }
    .opacity(member.isActive ? 1 : DesignMetrics.disabledOpacity)
  }

  private var roleTitle: String {
    switch member.role {
    case .owner:
      return L10n.string("media.detail.role.owner")
    case .contributor:
      return L10n.string("media.detail.role.contributor")
    }
  }
}
