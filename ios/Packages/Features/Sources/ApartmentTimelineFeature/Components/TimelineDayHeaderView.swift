import DesignSystem
import SwiftUI

struct TimelineDayHeaderView: View {
  let title: String

  var body: some View {
    HStack {
      Text(title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, ApartmentTimelineConstants.dayHeaderVerticalPadding)
        .glassEffect(.regular, in: .capsule)
      Spacer()
    }
    .padding(.vertical, Spacing.xxs)
  }
}
