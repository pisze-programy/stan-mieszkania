import SwiftUI

public enum ToastBannerStyle: Sendable, Equatable {
  case info
  case error
}

public struct ToastBanner: View {
  private static let maxLineCount: Int = 3

  private let message: String
  private let style: ToastBannerStyle
  private let onDismiss: (() -> Void)?

  public init(
    message: String,
    style: ToastBannerStyle = .info,
    onDismiss: (() -> Void)? = nil
  ) {
    self.message = message
    self.style = style
    self.onDismiss = onDismiss
  }

  public var body: some View {
    HStack(spacing: Spacing.sm) {
      Image(systemName: iconName)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(iconColor)

      Text(message)
        .font(.footnote.weight(.medium))
        .foregroundStyle(.primary)
        .lineLimit(Self.maxLineCount)
        .frame(maxWidth: .infinity, alignment: .leading)

      if let onDismiss {
        Button(action: onDismiss) {
          Image(systemName: "xmark")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string("common.close"))
      }
    }
    .padding(.horizontal, Spacing.md)
    .padding(.vertical, Spacing.sm)
    .glassEffect(.regular, in: .capsule)
  }

  private var iconName: String {
    switch style {
    case .info:
      return "info.circle.fill"
    case .error:
      return "exclamationmark.triangle.fill"
    }
  }

  private var iconColor: Color {
    switch style {
    case .info:
      return Color.accentColor
    case .error:
      return .red
    }
  }
}
