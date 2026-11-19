import DesignSystem
import SwiftUI

struct LocalOnlyInfoSheetView: View {
  private static let sectionSpacing: CGFloat = 20
  private static let heroIconSize: CGFloat = 44
  private static let rowIconSize: CGFloat = 22
  private static let rowIconColumnWidth: CGFloat = 28

  let canUploadToCloud: Bool
  let isUploadingToCloud: Bool
  let onUploadToCloud: () -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: Self.sectionSpacing) {
        Image(systemName: "icloud.slash")
          .font(.system(size: Self.heroIconSize))
          .foregroundStyle(.secondary)

        Text(L10n.string("local.info.title"))
          .font(.title2.bold())
          .multilineTextAlignment(.center)

        VStack(alignment: .leading, spacing: Spacing.md) {
          infoRow(
            systemImage: "iphone",
            title: L10n.string("local.info.device.title"),
            detail: L10n.string("local.info.device.detail")
          )
          infoRow(
            systemImage: "clock.badge.exclamationmark",
            title: L10n.string("local.info.unverified.title"),
            detail: L10n.string("local.info.unverified.detail")
          )
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Text(L10n.string("local.info.footer"))
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)

        if canUploadToCloud {
          GlassActionButton(
            title: L10n.string("media.detail.upload.cta"),
            systemImage: "icloud.and.arrow.up",
            variant: .primary,
            isLoading: isUploadingToCloud,
            action: onUploadToCloud
          )
        }
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
        .foregroundStyle(.secondary)
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
