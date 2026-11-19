import DesignSystem
import Domain
import SwiftUI

struct ApartmentCardView: View {
  private static let roleBadgeOpacity: Double = 0.14

  let item: ApartmentListItem

  var body: some View {
    GlassCard(cornerRadius: CornerRadius.lg, padding: Spacing.md) {
      VStack(alignment: .leading, spacing: Spacing.xs) {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
          Text(item.apartment.name)
            .font(Typography.cardTitle)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)

          Text(roleLabel)
            .font(Typography.badge)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(.secondary.opacity(Self.roleBadgeOpacity), in: .capsule)
        }

        Text(
          L10n.format("apartments.card.subtitle", item.apartment.street, item.apartment.city)
        )
        .font(Typography.subheadline)
        .foregroundStyle(.secondary)

        HStack(spacing: Spacing.xs) {
          Image(systemName: "photo.stack")
            .font(Typography.caption)
          Text(L10n.photoCount(item.photoCount))
            .font(Typography.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.top, Spacing.xxs)
      }
    }
  }

  private var roleLabel: String {
    switch item.apartment.role {
    case .owner:
      return L10n.string("media.detail.role.owner")
    case .contributor:
      return L10n.string("media.detail.role.contributor")
    }
  }
}
