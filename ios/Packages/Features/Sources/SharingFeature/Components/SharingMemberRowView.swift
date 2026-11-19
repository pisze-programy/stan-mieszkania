import DesignSystem
import Domain
import SwiftUI

struct SharingMemberRowView: View {
  let member: ApartmentMember
  let isRevoking: Bool

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
          .foregroundStyle(member.isActive ? .primary : .secondary)

        Text(roleTitle)
          .font(Typography.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if isRevoking {
        ProgressView()
          .controlSize(.small)
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
