import SwiftUI

public enum VerifiedBadgeStyle: Sendable {
  case compact
  case labeled
}

public struct VerifiedBadgeView: View {
  private static let compactLabel: String = "V"
  private static let badgeTintOpacity: Double = 0.16

  private let style: VerifiedBadgeStyle

  public init(style: VerifiedBadgeStyle = .compact) {
    self.style = style
  }

  public var body: some View {
    HStack(spacing: Spacing.xxs) {
      Image(systemName: "checkmark.seal.fill")
        .font(Typography.badge)
      Text(labelText)
        .font(Typography.badge)
    }
    .foregroundStyle(.green)
    .padding(.horizontal, Spacing.xs)
    .padding(.vertical, Spacing.xxs)
    .background(.green.opacity(Self.badgeTintOpacity), in: .capsule)
    .accessibilityLabel(L10n.string("media.detail.status.verified"))
  }

  private var labelText: String {
    switch style {
    case .compact:
      return Self.compactLabel
    case .labeled:
      return L10n.string("media.detail.status.verified")
    }
  }
}
