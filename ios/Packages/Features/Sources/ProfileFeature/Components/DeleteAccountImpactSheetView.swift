import DesignSystem
import SwiftUI

struct DeleteAccountImpactSheetView: View {
  private static let warningIconSize: CGFloat = 44

  let onContinueTapped: () -> Void

  var body: some View {
    NavigationStack {
      VStack(spacing: Spacing.lg) {
        Spacer()

        SurfaceCard(cornerRadius: CornerRadius.card, padding: Spacing.lg) {
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

        GlassActionButton(
          title: L10n.string("profile.delete.step1.continue"),
          systemImage: "trash.fill",
          variant: .destructive,
          action: onContinueTapped
        )
      }
      .padding(Spacing.lg)
      .appCanvas()
      .navigationTitle(L10n.string("profile.delete.account"))
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }
}
