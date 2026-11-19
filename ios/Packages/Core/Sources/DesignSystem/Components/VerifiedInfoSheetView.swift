import SwiftUI

public struct VerifiedInfoSheetView: View {
  private static let sectionSpacing: CGFloat = 20
  private static let heroIconSize: CGFloat = 44
  private static let rowIconSize: CGFloat = 22
  private static let rowIconColumnWidth: CGFloat = 28

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(spacing: Self.sectionSpacing) {
        Image(systemName: "checkmark.seal.fill")
          .font(.system(size: Self.heroIconSize))
          .foregroundStyle(.green)

        Text(L10n.string("verified.info.title"))
          .font(.title2.bold())
          .multilineTextAlignment(.center)

        VStack(alignment: .leading, spacing: Spacing.md) {
          infoRow(
            systemImage: "lock.icloud",
            title: L10n.string("verified.info.cloud.title"),
            detail: L10n.string("verified.info.cloud.detail")
          )
          infoRow(
            systemImage: "clock.badge.checkmark",
            title: L10n.string("verified.info.server.title"),
            detail: L10n.string("verified.info.server.detail")
          )
          infoRow(
            systemImage: "person.crop.circle.badge.checkmark",
            title: L10n.string("verified.info.author.title"),
            detail: L10n.string("verified.info.author.detail")
          )
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Text(L10n.string("verified.info.footer"))
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(Spacing.lg)
      .frame(maxWidth: .infinity)
    }
    .appCanvas()
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
  }

  private func infoRow(systemImage: String, title: String, detail: String) -> some View {
    HStack(alignment: .top, spacing: Spacing.sm) {
      Image(systemName: systemImage)
        .font(.system(size: Self.rowIconSize))
        .foregroundStyle(.green)
        .frame(width: Self.rowIconColumnWidth, alignment: .center)

      VStack(alignment: .leading, spacing: Spacing.xxs) {
        Text(title)
          .font(.body)
        Text(detail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }
}
