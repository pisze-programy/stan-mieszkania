import SwiftUI

public enum GlassActionButtonVariant: Sendable {
  case primary
  case secondary
  case destructive
}

public struct GlassActionButton: View {
  private static let subtitleLineLimit: Int = 2

  private let title: String
  private let subtitle: String?
  private let systemImage: String?
  private let variant: GlassActionButtonVariant
  private let isLoading: Bool
  private let isDisabled: Bool
  private let expandsHorizontally: Bool
  private let controlSize: ControlSize
  private let action: () -> Void

  public init(
    title: String,
    subtitle: String? = nil,
    systemImage: String? = nil,
    variant: GlassActionButtonVariant = .primary,
    isLoading: Bool = false,
    isDisabled: Bool = false,
    expandsHorizontally: Bool = true,
    controlSize: ControlSize = .large,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.subtitle = subtitle
    self.systemImage = systemImage
    self.variant = variant
    self.isLoading = isLoading
    self.isDisabled = isDisabled
    self.expandsHorizontally = expandsHorizontally
    self.controlSize = controlSize
    self.action = action
  }

  public var body: some View {
    buttonWithStyle
      .controlSize(controlSize)
      .disabled(isDisabled || isLoading)
  }

  @ViewBuilder
  private var buttonWithStyle: some View {
    switch variant {
    case .primary:
      baseButton
        .buttonStyle(.glassProminent)
    case .secondary:
      baseButton
        .buttonStyle(.glass)
    case .destructive:
      baseButton
        .buttonStyle(.glassProminent)
        .tint(.red)
    }
  }

  private var baseButton: some View {
    Button(action: action) {
      ZStack {
        VStack(spacing: Spacing.xxs) {
          HStack(spacing: Spacing.xs) {
            if let systemImage {
              Image(systemName: systemImage)
            }
            Text(title)
              .font(Typography.callout.weight(.semibold))
          }

          if let subtitle {
            Text(subtitle)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .lineLimit(Self.subtitleLineLimit)
          }
        }
        .opacity(isLoading ? 0 : 1)

        if isLoading {
          ProgressView()
            .controlSize(.small)
        }
      }
      .frame(maxWidth: expandsHorizontally ? .infinity : nil)
      .animation(Motion.fade, value: isLoading)
    }
  }
}
