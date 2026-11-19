import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

public enum Surface: Sendable {
  #if canImport(UIKit)
    public static let canvas = Color(uiColor: .systemGroupedBackground)
    public static let card = Color(uiColor: .secondarySystemGroupedBackground)
    public static let inset = Color(uiColor: .tertiarySystemGroupedBackground)
    public static let separator = Color(uiColor: .separator)
  #elseif canImport(AppKit)
    public static let canvas = Color(nsColor: .windowBackgroundColor)
    public static let card = Color(nsColor: .controlBackgroundColor)
    public static let inset = Color(nsColor: .textBackgroundColor)
    public static let separator = Color(nsColor: .separatorColor)
  #endif
}
