import DesignSystem
import SwiftUI

struct LocationPermissionSheetView: View {
  let onAllowTapped: () -> Void
  let onSkipTapped: () -> Void

  var body: some View {
    VStack(spacing: Spacing.lg) {
      Spacer()

      SurfaceCard(cornerRadius: CornerRadius.card, padding: Spacing.lg) {
        VStack(spacing: Spacing.md) {
          Image(systemName: "location.circle.fill")
            .font(.system(size: CaptureConstants.heroIconSize))
            .foregroundStyle(.tint)

          Text(L10n.string("capture.gps.sheet.title"))
            .font(Typography.sectionHeader)
            .multilineTextAlignment(.center)

          Text(L10n.string("capture.gps.explanation"))
            .font(Typography.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

          VStack(spacing: Spacing.sm) {
            GlassActionButton(
              title: L10n.string("capture.gps.allow.cta"),
              systemImage: "location.fill",
              variant: .primary,
              action: onAllowTapped
            )
            GlassActionButton(
              title: L10n.string("capture.gps.skip.cta"),
              variant: .secondary,
              action: onSkipTapped
            )
          }
          .padding(.top, Spacing.xs)
        }
      }

      Spacer()
    }
    .padding(Spacing.lg)
    .appCanvas()
  }
}
