import DesignSystem
import SwiftUI

struct SummaryActionBarView: View {
  let isSaving: Bool
  let showsCaptureAnother: Bool
  let onSaveLocal: () -> Void
  let onSaveCloud: () -> Void
  let onSaveAndCaptureNext: () -> Void

  var body: some View {
    VStack(spacing: Spacing.xs) {
      // Decision S2-2 & S2-7: Dual Liquid Glass bar with Lokalnie left and Do chmury right.
      HStack(spacing: Spacing.sm) {
        GlassActionButton(
          title: L10n.string("media.summary.action.local"),
          systemImage: "iphone",
          variant: .secondary,
          isLoading: isSaving,
          isDisabled: isSaving,
          action: onSaveLocal
        )

        GlassActionButton(
          title: L10n.string("media.summary.action.cloud"),
          systemImage: "icloud.and.arrow.up",
          variant: .primary,
          isLoading: isSaving,
          isDisabled: isSaving,
          action: onSaveCloud
        )
      }

      if showsCaptureAnother {
        // Decision S2-6: Quick camera loop to reduce friction during 30+ photo handovers.
        GlassActionButton(
          title: L10n.string("capture.next.cta"),
          systemImage: "camera.on.rectangle",
          variant: .secondary,
          isDisabled: isSaving,
          action: onSaveAndCaptureNext
        )
      }
    }
    .padding(.horizontal, Spacing.md)
    .padding(.vertical, Spacing.sm)
  }
}
