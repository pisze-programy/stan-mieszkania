import DesignSystem
import SwiftUI

struct SummarySaveSheetView: View {
  private static let topPadding: CGFloat = 28
  private static let horizontalPadding: CGFloat = 20
  private static let bottomPadding: CGFloat = 16
  private static let errorSlotHeight: CGFloat = 18

  let savingMode: MediaSummarySaveMode?
  let errorMessage: String?
  let onSelect: (MediaSummarySaveMode) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.sm) {
      Text(L10n.string("media.summary.save.sheet.title"))
        .font(.headline)
        .frame(maxWidth: .infinity)

      SaveDestinationButton(
        mode: .localOnly,
        savingMode: savingMode,
        onSelect: onSelect
      )

      SaveDestinationButton(
        mode: .cloud,
        savingMode: savingMode,
        onSelect: onSelect
      )

      StableSlot(minHeight: Self.errorSlotHeight) {
        if let errorMessage {
          Text(errorMessage)
            .font(.footnote)
            .foregroundStyle(.red)
        }
      }
      .animation(Motion.fade, value: errorMessage)
    }
    .padding(.top, Self.topPadding)
    .padding(.horizontal, Self.horizontalPadding)
    .padding(.bottom, Self.bottomPadding)
    .selfSizingSheet()
  }
}

private struct SaveDestinationButton: View {
  private static let contentSpacing: CGFloat = 14
  private static let iconSlotSize: CGFloat = 40
  private static let textSpacing: CGFloat = 2
  private static let subtitleOpacity: Double = 0.8
  private static let minRowHeight: CGFloat = 64
  private static let buttonCornerRadius: CGFloat = 18

  let mode: MediaSummarySaveMode
  let savingMode: MediaSummarySaveMode?
  let onSelect: (MediaSummarySaveMode) -> Void

  private var isLoading: Bool {
    savingMode == mode
  }

  private var systemImage: String {
    mode == .cloud ? "icloud.and.arrow.up" : "iphone"
  }

  private var title: String {
    L10n.string(mode == .cloud ? "media.summary.action.cloud" : "media.summary.action.local")
  }

  private var subtitle: String {
    L10n.string(
      mode == .cloud
        ? "media.summary.action.cloud.subtitle"
        : "media.summary.action.local.subtitle"
    )
  }

  var body: some View {
    let baseButton = Button {
      onSelect(mode)
    } label: {
      HStack(spacing: Self.contentSpacing) {
        ZStack {
          Image(systemName: systemImage)
            .opacity(isLoading ? 0 : 1)
          if isLoading {
            ProgressView()
          }
        }
        .font(.title3.weight(.semibold))
        .frame(width: Self.iconSlotSize, height: Self.iconSlotSize)

        VStack(alignment: .leading, spacing: Self.textSpacing) {
          Text(title)
            .font(.body.weight(.semibold))
          Text(subtitle)
            .font(.footnote)
            .opacity(Self.subtitleOpacity)
        }

        Spacer(minLength: 0)
      }
      .padding(.horizontal, Spacing.md)
      .frame(maxWidth: .infinity, minHeight: Self.minRowHeight, alignment: .leading)
      .contentShape(.rect(cornerRadius: Self.buttonCornerRadius, style: .continuous))
    }
    .buttonBorderShape(.roundedRectangle(radius: Self.buttonCornerRadius))
    .disabled(savingMode != nil)

    if mode == .cloud {
      baseButton.buttonStyle(.glassProminent)
    } else {
      baseButton.buttonStyle(.glass)
    }
  }
}
