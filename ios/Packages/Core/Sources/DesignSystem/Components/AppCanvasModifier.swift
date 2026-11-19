import SwiftUI

public struct AppCanvasModifier: ViewModifier {
  public init() {}

  public func body(content: Content) -> some View {
    content
      .background(Surface.canvas.ignoresSafeArea())
      .scrollContentBackground(.hidden)
  }
}

extension View {
  public func appCanvas() -> some View {
    modifier(AppCanvasModifier())
  }
}
