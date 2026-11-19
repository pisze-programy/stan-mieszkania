import DesignSystem
import SwiftUI

struct DeleteAccountImpactSheetView: View {
  private static let warningIconSize: CGFloat = 44

  let onContinueTapped: () -> Void
  let onCancelTapped: () -> Void

  var body: some View {
    NavigationStack {
      VStack(spacing: Spacing.lg) {
        Spacer()

        GlassCard(cornerRadius: CornerRadius.xl, padding: Spacing.lg) {
          VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.shield.fill")
              .font(.system(size: Self.warningIconSize))
              .foregroundStyle(.red)

            Text(L10n.string("profile.delete.confirm.title"))
              .font(Typography.sectionHeader)
              .multilineTextAlignment(.center)

            Text(L10n.string("profile.delete.confirm.message"))
              .font(Typography.body)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
        }

        Spacer()

        VStack(spacing: Spacing.sm) {
          GlassActionButton(
            title: L10n.string("profile.delete.step1.continue"),
            systemImage: "trash.fill",
            variant: .destructive,
            action: onContinueTapped
          )
          GlassActionButton(
            title: L10n.string("apartments.create.cancel.cta"),
            variant: .secondary,
            action: onCancelTapped
          )
        }
      }
      .padding(Spacing.lg)
      .navigationTitle(L10n.string("profile.delete.account"))
    }
  }
}
