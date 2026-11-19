import DesignSystem
import SwiftUI

struct TimelineDayHeaderView: View {
  let title: String

  var body: some View {
    HStack {
      Text(title)
        .font(Typography.sectionHeader)
        .foregroundStyle(.primary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .glassEffect(.regular, in: .capsule)
      Spacer()
    }
    .padding(.vertical, Spacing.xxs)
  }
}
