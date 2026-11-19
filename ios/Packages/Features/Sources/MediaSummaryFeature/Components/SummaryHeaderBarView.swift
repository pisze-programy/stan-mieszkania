import DesignSystem
import SwiftUI

struct SummaryHeaderBarView: View {
  let isSaving: Bool
  let isMultiPhoto: Bool
  let selectedIndex: Int
  let pageCount: Int
  let onRetake: () -> Void
  let onSelectPage: (Int) -> Void

  var body: some View {
    HStack {
      Button(action: onRetake) {
        Label(L10n.string("capture.retake.cta"), systemImage: "arrow.counterclockwise")
          .font(Typography.callout.weight(.medium))
      }
      .buttonStyle(.glass)
      .disabled(isSaving)

      Spacer()

      if isMultiPhoto {
        pagerControls
      }
    }
  }

  private var pagerControls: some View {
    HStack(spacing: Spacing.xs) {
      Button {
        onSelectPage(selectedIndex - 1)
      } label: {
        Image(systemName: "chevron.left")
      }
      .disabled(selectedIndex <= 0)

      Text("\(selectedIndex + 1)/\(pageCount)")
        .font(Typography.badge)
        .monospacedDigit()
        .contentTransition(.numericText())

      Button {
        onSelectPage(selectedIndex + 1)
      } label: {
        Image(systemName: "chevron.right")
      }
      .disabled(selectedIndex >= pageCount - 1)
    }
    .padding(.horizontal, Spacing.xs)
    .padding(.vertical, Spacing.xxs)
    .glassEffect(.regular, in: .capsule)
  }
}
