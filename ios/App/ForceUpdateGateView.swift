import DesignSystem
import SwiftUI

struct ForceUpdateGateView: View {
  let minVersion: String?

  // Architecture A19: Non-destructive force-update screen keeping local SQLiteData intact.
  var body: some View {
    VStack(spacing: Spacing.lg) {
      Spacer()

      SurfaceCard(cornerRadius: CornerRadius.card, padding: Spacing.lg) {
        VStack(spacing: Spacing.md) {
          Image(systemName: "arrow.down.app.fill")
            .font(.system(size: AppConstants.forceUpdateIconSize))
            .foregroundStyle(.tint)

          Text(L10n.string("app.update.title"))
            .font(Typography.sectionHeader)
            .multilineTextAlignment(.center)

          Text(L10n.string("app.update.message"))
            .font(Typography.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

          if let minVersion, !minVersion.isEmpty {
            Text(minVersion)
              .font(Typography.caption.monospaced())
              .foregroundStyle(.secondary)
          }
        }
        .frame(maxWidth: .infinity)
      }
      .padding(.horizontal, Spacing.lg)

      Spacer()
    }
  }
}
