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
        size: DesignMetrics.avatarMediumSize
      )

      Text(member.displayName)
        .font(.body)
        .foregroundStyle(member.isActive ? .primary : .secondary)
        .frame(maxWidth: .infinity, alignment: .leading)

      if isRevoking {
        ProgressView()
          .controlSize(.small)
      }
    }
    .opacity(member.isActive ? 1 : DesignMetrics.disabledOpacity)
  }
}
