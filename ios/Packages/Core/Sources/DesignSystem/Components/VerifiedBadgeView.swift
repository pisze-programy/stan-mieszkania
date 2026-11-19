import SwiftUI

public enum VerifiedBadgeStyle: Sendable {
  case seal
  case inline
  case labeled
}

public struct VerifiedBadgeView: View {
  private static let sealSize: CGFloat = 24
  private static let labeledHorizontalPadding: CGFloat = 10
  private static let labeledVerticalPadding: CGFloat = 5
  private static let labeledTintOpacity: Double = 0.14
  private static let minTapTargetSize: CGFloat = 44

  private let style: VerifiedBadgeStyle
  private let onTap: (() -> Void)?

  public init(
    style: VerifiedBadgeStyle,
    onTap: (() -> Void)? = nil
  ) {
    self.style = style
    self.onTap = onTap
  }

  @ViewBuilder
  public var body: some View {
    if let onTap {
      Button(action: onTap) {
        badgeContent
          .frame(minHeight: Self.minTapTargetSize)
          .contentShape(.capsule)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(L10n.string("media.detail.status.verified"))
    } else {
      badgeContent
        .accessibilityLabel(L10n.string("media.detail.status.verified"))
    }
  }

  @ViewBuilder
  private var badgeContent: some View {
    switch style {
    case .seal:
      Image(systemName: "checkmark.seal.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)
        .frame(width: Self.sealSize, height: Self.sealSize)
        .glassEffect(.regular, in: .circle)
    case .inline:
      Image(systemName: "checkmark.seal.fill")
        .font(.footnote)
        .foregroundStyle(.green)
    case .labeled:
      HStack(spacing: Spacing.xxs) {
        Image(systemName: "checkmark.seal.fill")
        Text(L10n.string("media.detail.status.verified"))
        if onTap != nil {
          Image(systemName: "info.circle")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      .font(.footnote.weight(.semibold))
      .foregroundStyle(.green)
      .padding(.horizontal, Self.labeledHorizontalPadding)
      .padding(.vertical, Self.labeledVerticalPadding)
      .background(.green.opacity(Self.labeledTintOpacity), in: .capsule)
    }
  }
}
