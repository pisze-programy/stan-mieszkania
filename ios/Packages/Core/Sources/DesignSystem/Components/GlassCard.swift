import SwiftUI

public struct GlassCard<Content: View>: View {
  private let cornerRadius: CGFloat
  private let padding: CGFloat
  private let content: Content

  public init(
    cornerRadius: CGFloat = CornerRadius.lg,
    padding: CGFloat = Spacing.md,
    @ViewBuilder content: () -> Content
  ) {
    self.cornerRadius = cornerRadius
    self.padding = padding
    self.content = content()
  }

  public var body: some View {
    content
      .padding(padding)
      .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
  }
}
