import SwiftUI

public struct GlassFloatingActionButton: View {
  private let systemImage: String
  private let accessibilityLabel: String
  private let accessibilityHint: String?
  private let action: () -> Void

  public init(
    systemImage: String = "plus",
    accessibilityLabel: String,
    accessibilityHint: String? = nil,
    action: @escaping () -> Void
  ) {
    self.systemImage = systemImage
    self.accessibilityLabel = accessibilityLabel
    self.accessibilityHint = accessibilityHint
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.title2.weight(.semibold))
        .frame(
          width: DesignMetrics.floatingActionButtonSize,
          height: DesignMetrics.floatingActionButtonSize
        )
    }
    .glassEffect(.regular.interactive(), in: .circle)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint(accessibilityHint ?? "")
  }
}
