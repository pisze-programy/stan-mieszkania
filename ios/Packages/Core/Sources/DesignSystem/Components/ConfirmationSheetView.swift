import SwiftUI

public struct ConfirmationSheetContent: Hashable, Sendable {
  public enum Tone: Hashable, Sendable {
    case destructive
    case neutral
  }

  public let systemImage: String?
  public let title: String
  public let message: String?
  public let confirmTitle: String
  public let tone: Tone

  public var confirmButtonVariant: GlassActionButtonVariant {
    tone == .destructive ? .destructive : .primary
  }

  public init(
    systemImage: String? = nil,
    title: String,
    message: String? = nil,
    confirmTitle: String,
    tone: Tone = .destructive
  ) {
    self.systemImage = systemImage
    self.title = title
    self.message = message
    self.confirmTitle = confirmTitle
    self.tone = tone
  }
}

public struct ConfirmationSheetView: View {
  private static let iconCircleSize: CGFloat = 56
  private static let iconCircleOpacity: Double = 0.15
  private static let topPadding: CGFloat = 32
  private static let horizontalPadding: CGFloat = 24
  private static let bottomPadding: CGFloat = 16
  private static let buttonSpacing: CGFloat = 10

  private let content: ConfirmationSheetContent
  private let isConfirming: Bool
  private let onConfirm: () -> Void
  private let onCancel: () -> Void

  public init(
    content: ConfirmationSheetContent,
    isConfirming: Bool = false,
    onConfirm: @escaping () -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.content = content
    self.isConfirming = isConfirming
    self.onConfirm = onConfirm
    self.onCancel = onCancel
  }

  private var toneColor: Color {
    content.tone == .destructive ? .red : Color.accentColor
  }

  public var body: some View {
    VStack(spacing: Spacing.md) {
      if let systemImage = content.systemImage {
        Image(systemName: systemImage)
          .font(.title2.weight(.semibold))
          .foregroundStyle(toneColor)
          .frame(width: Self.iconCircleSize, height: Self.iconCircleSize)
          .background(toneColor.opacity(Self.iconCircleOpacity), in: .circle)
      }

      Text(content.title)
        .font(.title3.weight(.semibold))
        .multilineTextAlignment(.center)

      if let message = content.message {
        Text(message)
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }

      VStack(spacing: Self.buttonSpacing) {
        GlassActionButton(
          title: content.confirmTitle,
          variant: content.confirmButtonVariant,
          isLoading: isConfirming,
          controlSize: .large,
          action: onConfirm
        )

        GlassActionButton(
          title: L10n.string("confirmation.cancel"),
          variant: .secondary,
          isDisabled: isConfirming,
          controlSize: .large,
          action: onCancel
        )
      }
    }
    .id(content)
    .transition(.opacity)
    .animation(Motion.smooth, value: content)
    .padding(.top, Self.topPadding)
    .padding(.horizontal, Self.horizontalPadding)
    .padding(.bottom, Self.bottomPadding)
    .selfSizingSheet()
    .interactiveDismissDisabled(isConfirming)
  }
}

private struct ConfirmationSheetModifier: ViewModifier {
  @Binding var isPresented: Bool
  let isConfirming: Bool
  let contentProvider: () -> ConfirmationSheetContent
  let onConfirm: () -> Void
  let onDismiss: (() -> Void)?

  @State private var cachedContent: ConfirmationSheetContent?

  func body(content: Content) -> some View {
    content
      .onChange(of: isPresented) { _, presented in
        if presented {
          cachedContent = contentProvider()
        }
      }
      .sheet(
        isPresented: $isPresented,
        onDismiss: {
          cachedContent = nil
          onDismiss?()
        },
        content: {
          let activeContent = isPresented ? contentProvider() : (cachedContent ?? contentProvider())
          ConfirmationSheetView(
            content: activeContent,
            isConfirming: isConfirming,
            onConfirm: onConfirm,
            onCancel: { isPresented = false }
          )
          .onAppear {
            if isPresented {
              cachedContent = activeContent
            }
          }
          .onChange(of: activeContent) { _, updated in
            if isPresented {
              cachedContent = updated
            }
          }
        }
      )
  }
}

extension View {
  public func confirmationSheet(
    isPresented: Binding<Bool>,
    isConfirming: Bool = false,
    onDismiss: (() -> Void)? = nil,
    content: @escaping () -> ConfirmationSheetContent,
    onConfirm: @escaping () -> Void
  ) -> some View {
    modifier(
      ConfirmationSheetModifier(
        isPresented: isPresented,
        isConfirming: isConfirming,
        contentProvider: content,
        onConfirm: onConfirm,
        onDismiss: onDismiss
      )
    )
  }
}
