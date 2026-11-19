import DesignSystem
import SwiftUI

struct InviteCodeCardView: View {
  let inviteCode: String?
  let shareMessageText: String?
  let showCopiedFeedback: Bool
  let isResettingCode: Bool
  let isOwner: Bool
  let onCopyTapped: () -> Void
  let onResetTapped: () -> Void

  var body: some View {
    SurfaceCard(cornerRadius: CornerRadius.card, padding: Spacing.md) {
      VStack(alignment: .leading, spacing: Spacing.md) {
        Text(L10n.string("sharing.code.label"))
          .font(Typography.subheadline)
          .foregroundStyle(.secondary)

        if let inviteCode {
          codeContent(inviteCode)
        } else {
          HStack(spacing: Spacing.xs) {
            ProgressView()
              .controlSize(.small)
            Text(L10n.string("sharing.code.pending"))
              .font(Typography.callout)
              .foregroundStyle(.secondary)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder
  private func codeContent(_ code: String) -> some View {
    VStack(alignment: .leading, spacing: Spacing.sm) {
      Text(code)
        .font(Typography.monospacedCode)
        .textSelection(.enabled)

      if showCopiedFeedback {
        Label(L10n.string("sharing.code.copied"), systemImage: "checkmark.circle.fill")
          .font(Typography.caption)
          .foregroundStyle(.green)
      }

      HStack(spacing: Spacing.sm) {
        GlassActionButton(
          title: L10n.string("sharing.code.copy"),
          systemImage: "doc.on.doc",
          variant: .primary,
          action: onCopyTapped
        )

        if let shareMessageText {
          ShareLink(item: shareMessageText) {
            HStack(spacing: Spacing.xs) {
              Image(systemName: "message.fill")
              Text(L10n.string("sharing.sms.cta"))
                .font(Typography.callout.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xs)
          }
          .buttonStyle(.glass)
        }
      }

      if isOwner {
        GlassActionButton(
          title: L10n.string("sharing.code.reset.cta"),
          systemImage: "arrow.clockwise",
          variant: .secondary,
          isLoading: isResettingCode,
          action: onResetTapped
        )
      }
    }
  }
}
