import DesignSystem
import SwiftUI

struct SummaryPagerCapsuleView: View {
  let selectedIndex: Int
  let pageCount: Int
  let onSelectPage: (Int) -> Void

  var body: some View {
    HStack(spacing: Spacing.xxs) {
      Button {
        onSelectPage(selectedIndex - 1)
      } label: {
        Image(systemName: "chevron.left")
          .font(.footnote.weight(.semibold))
          .frame(
            width: MediaSummaryConstants.pagerButtonHitSize,
            height: MediaSummaryConstants.pagerButtonHitSize
          )
          .contentShape(.circle)
      }
      .buttonStyle(.plain)
      .disabled(selectedIndex <= 0)
      .accessibilityLabel(L10n.string("media.summary.pager.previous"))

      Text(
        L10n.format(
          "media.summary.pager.format",
          selectedIndex + 1,
          pageCount
        )
      )
      .font(Typography.badge)
      .monospacedDigit()
      .contentTransition(.numericText())
      .padding(.horizontal, Spacing.xxs)

      Button {
        onSelectPage(selectedIndex + 1)
      } label: {
        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .frame(
            width: MediaSummaryConstants.pagerButtonHitSize,
            height: MediaSummaryConstants.pagerButtonHitSize
          )
          .contentShape(.circle)
      }
      .buttonStyle(.plain)
      .disabled(selectedIndex >= pageCount - 1)
      .accessibilityLabel(L10n.string("media.summary.pager.next"))
    }
    .padding(.horizontal, Spacing.xxs)
    .glassEffect(.regular.interactive(), in: .capsule)
  }
}
