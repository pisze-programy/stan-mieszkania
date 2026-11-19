import DesignSystem
import Domain
import SwiftUI

struct ApartmentCardView: View {
  private static let roleBadgeOpacity: Double = 0.14

  let item: ApartmentListItem

  var body: some View {
    SurfaceCard(cornerRadius: CornerRadius.card, padding: Spacing.md) {
      HStack(alignment: .center, spacing: Spacing.sm) {
        VStack(alignment: .leading, spacing: Spacing.xs) {
          HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(item.apartment.name)
              .font(Typography.cardTitle)
              .foregroundStyle(.primary)
              .frame(maxWidth: .infinity, alignment: .leading)

            if item.apartment.role == .contributor {
              Text(L10n.string("media.detail.role.contributor"))
                .font(Typography.badge)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs)
                .background(.secondary.opacity(Self.roleBadgeOpacity), in: .capsule)
            }
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

        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
  }
}
