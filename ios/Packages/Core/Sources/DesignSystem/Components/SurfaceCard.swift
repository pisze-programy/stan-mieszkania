import SwiftUI

public struct SurfaceCard<Content: View>: View {
  private let cornerRadius: CGFloat
  private let padding: CGFloat
  private let content: Content

  public init(
    cornerRadius: CGFloat = CornerRadius.card,
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
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        Surface.card,
        in: .rect(cornerRadius: cornerRadius, style: .continuous)
      )
  }
}
