import SwiftUI

public struct StableSlot<Content: View>: View {
  private let minHeight: CGFloat
  private let alignment: Alignment
  private let content: Content

  public init(
    minHeight: CGFloat = DesignMetrics.stableSlotMinHeight,
    alignment: Alignment = .leading,
    @ViewBuilder content: () -> Content
  ) {
    self.minHeight = minHeight
    self.alignment = alignment
    self.content = content()
  }

  public var body: some View {
    ZStack(alignment: alignment) {
      Text(" ")
        .hidden()
      content
        .transition(.opacity)
    }
    .frame(maxWidth: .infinity, minHeight: minHeight, alignment: alignment)
  }
}
