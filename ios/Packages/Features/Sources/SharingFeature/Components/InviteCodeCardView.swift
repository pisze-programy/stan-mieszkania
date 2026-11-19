import DesignSystem
import SwiftUI

struct InviteCodeCardView: View {
  private static let codeFontSize: CGFloat = 34
  private static let codeKerning: CGFloat = 2
  private static let verticalPadding: CGFloat = 20
  private static let feedbackSlotHeight: CGFloat = 18

  let inviteCode: String?
  let shareMessageText: String?
  let showCopiedFeedback: Bool
  let showResetFeedback: Bool
  let onCopyTapped: () -> Void

  var body: some View {
    Group {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.sm)
      }
    }
  }

  private func codeContent(_ code: String) -> some View {
    VStack(spacing: Spacing.sm) {
      Button(action: onCopyTapped) {
        Text(code)
          .id(code)
          .transition(.opacity)
          .font(.system(size: Self.codeFontSize, weight: .semibold, design: .monospaced))
          .kerning(Self.codeKerning)
          .foregroundStyle(.primary)
          .frame(maxWidth: .infinity)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .animation(Motion.fade, value: code)
      .accessibilityHint(L10n.string("sharing.code.copy.a11yHint"))

      StableSlot(minHeight: Self.feedbackSlotHeight, alignment: .center) {
        if showCopiedFeedback {
          Label(
            L10n.string("sharing.code.copied.short"),
            systemImage: "checkmark.circle.fill"
          )
          .foregroundStyle(.green)
        } else if showResetFeedback {
          Label(
            L10n.string("sharing.code.reset.done"),
            systemImage: "checkmark.circle.fill"
          )
          .foregroundStyle(.green)
        }
      }
      .font(.footnote)
      .animation(Motion.fade, value: showCopiedFeedback)
      .animation(Motion.fade, value: showResetFeedback)

      if let shareMessageText {
        ShareLink(item: shareMessageText) {
          HStack(spacing: Spacing.xs) {
            Image(systemName: "square.and.arrow.up")
            Text(L10n.string("sharing.share.cta"))
          }
          .font(.body.weight(.semibold))
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
      }
    }
    .padding(.vertical, Self.verticalPadding)
    .frame(maxWidth: .infinity)
  }
}
