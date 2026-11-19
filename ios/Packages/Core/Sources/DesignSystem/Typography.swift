import SwiftUI

public enum Typography: Sendable {
  public static let screenTitle: Font = .largeTitle.weight(.bold)
  public static let sectionHeader: Font = .title3.weight(.semibold)
  public static let cardTitle: Font = .headline
  public static let body: Font = .body
  public static let callout: Font = .callout
  public static let subheadline: Font = .subheadline
  public static let footnote: Font = .footnote
  public static let caption: Font = .caption
  public static let badge: Font = .caption2.weight(.semibold)
  public static let monospacedCode: Font = .title3.monospaced().weight(.semibold)
  public static let markerNumber: Font = .caption.monospacedDigit().weight(.bold)
}
