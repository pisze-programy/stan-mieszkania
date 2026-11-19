import DesignSystem
import SwiftUI

struct SummaryActionBarView: View {
  let savingMode: MediaSummarySaveMode?
  let onSaveLocal: () -> Void
  let onSaveCloud: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      Text(L10n.string("media.summary.save.caption"))
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)

      // Decision S2-2 & S2-7: Dual Liquid Glass bar with Lokalnie left and Chmura right.
      GlassEffectContainer(spacing: Spacing.sm) {
        HStack(spacing: Spacing.sm) {
          GlassActionButton(
            title: L10n.string("media.summary.action.local"),
            subtitle: L10n.string("media.summary.action.local.subtitle"),
            systemImage: "iphone",
            variant: .secondary,
            isLoading: savingMode == .localOnly,
            isDisabled: savingMode != nil,
            action: onSaveLocal
          )

          GlassActionButton(
            title: L10n.string("media.summary.action.cloud"),
            subtitle: L10n.string("media.summary.action.cloud.subtitle"),
            systemImage: "icloud.and.arrow.up",
            variant: .primary,
            isLoading: savingMode == .cloud,
            isDisabled: savingMode != nil,
            action: onSaveCloud
          )
        }
      }
    }
    .padding(.horizontal, Spacing.md)
    .padding(.vertical, Spacing.xs)
  }
}
