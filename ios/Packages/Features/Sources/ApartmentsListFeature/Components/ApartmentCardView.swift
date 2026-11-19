import DesignSystem
import Domain
import SwiftUI

struct ApartmentCardView: View {
  let item: ApartmentListItem

  var body: some View {
    SurfaceCard(cornerRadius: CornerRadius.card, padding: Spacing.md) {
      HStack(alignment: .center, spacing: Spacing.sm) {
        VStack(alignment: .leading, spacing: Spacing.xs) {
          Text(item.apartment.name)
            .font(Typography.cardTitle)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)

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
