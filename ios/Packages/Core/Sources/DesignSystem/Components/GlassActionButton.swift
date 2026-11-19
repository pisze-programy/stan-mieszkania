import SwiftUI

public enum GlassActionButtonVariant: Sendable {
  case primary
  case secondary
  case destructive
}

public struct GlassActionButton: View {
  private let title: String
  private let systemImage: String?
  private let variant: GlassActionButtonVariant
  private let isLoading: Bool
  private let isDisabled: Bool
  private let expandsHorizontally: Bool
  private let action: () -> Void

  public init(
    title: String,
    systemImage: String? = nil,
    variant: GlassActionButtonVariant = .primary,
    isLoading: Bool = false,
    isDisabled: Bool = false,
    expandsHorizontally: Bool = true,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.systemImage = systemImage
    self.variant = variant
    self.isLoading = isLoading
    self.isDisabled = isDisabled
    self.expandsHorizontally = expandsHorizontally
    self.action = action
  }

  public var body: some View {
    buttonWithStyle
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
      HStack(spacing: Spacing.xs) {
        if isLoading {
          ProgressView()
            .controlSize(.small)
        } else if let systemImage {
          Image(systemName: systemImage)
        }
        Text(title)
          .font(Typography.callout.weight(.semibold))
      }
      .frame(maxWidth: expandsHorizontally ? .infinity : nil)
      .padding(.vertical, Spacing.xs)
    }
  }
}
