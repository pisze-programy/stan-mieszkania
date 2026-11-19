import SwiftUI

public struct GlassIconButton: View {
  private let systemImage: String
  private let accessibilityLabel: String
  private let size: CGFloat
  private let action: () -> Void

  public init(
    systemImage: String,
    accessibilityLabel: String,
    size: CGFloat = DesignMetrics.glassIconButtonSize,
    action: @escaping () -> Void
  ) {
    self.systemImage = systemImage
    self.accessibilityLabel = accessibilityLabel
    self.size = size
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.body.weight(.semibold))
        .frame(width: size, height: size)
        .contentShape(.circle)
        .contentTransition(.symbolEffect(.replace))
    }
    .buttonStyle(.plain)
    .glassEffect(.regular.interactive(), in: .circle)
    .accessibilityLabel(accessibilityLabel)
  }
}
