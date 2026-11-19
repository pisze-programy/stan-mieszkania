import SwiftUI

public struct PressableCardButtonStyle: ButtonStyle {
  private static let pressedScale: CGFloat = 0.98
  private static let restScale: CGFloat = 1
  private static let pressedOpacity: Double = 0.85
  private static let restOpacity: Double = 1

  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .contentShape(.rect(cornerRadius: CornerRadius.card, style: .continuous))
      .scaleEffect(configuration.isPressed ? Self.pressedScale : Self.restScale)
      .opacity(configuration.isPressed ? Self.pressedOpacity : Self.restOpacity)
      .animation(Motion.snappy, value: configuration.isPressed)
  }
}
