import SwiftUI

#if os(iOS)
  import UIKit
#endif

extension View {
  public func selfSizingSheet() -> some View {
    modifier(SelfSizingSheetModifier())
  }
}

struct SelfSizingSheetModifier: ViewModifier {
  private static let fallbackHeight: CGFloat = 320
  private static let minHeight: CGFloat = 120
  private static let fallbackMaxHeight: CGFloat = 760
  private static let maxScreenFraction: CGFloat = 0.9
  private static let heightEpsilon: CGFloat = 1

  @State private var measuredHeight: CGFloat = fallbackHeight

  func body(content: Content) -> some View {
    let fitted =
      content
      .fixedSize(horizontal: false, vertical: true)
      .onGeometryChange(for: CGFloat.self) { proxy in
        proxy.size.height
      } action: { newHeight in
        let clamped = min(max(newHeight, Self.minHeight), Self.maximumSheetHeight())
        if abs(clamped - measuredHeight) > Self.heightEpsilon {
          measuredHeight = clamped
        }
      }

    ViewThatFits(in: .vertical) {
      fitted
      ScrollView {
        fitted
      }
    }
    .presentationDetents([.height(measuredHeight)])
    .presentationDragIndicator(.visible)
  }

  @MainActor
  private static func maximumSheetHeight() -> CGFloat {
    #if os(iOS)
      let screenHeight =
        UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?
        .screen.bounds.height
      if let screenHeight, screenHeight > 0 {
        return screenHeight * maxScreenFraction
      }
    #endif
    return fallbackMaxHeight
  }
}
