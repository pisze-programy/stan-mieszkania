import DesignSystem
import SwiftUI

struct SummaryMarkerControlsView: View {
  let markers: [SummaryDraftMarker]
  let selectedMarkerNumber: Int?
  let authorColorHex: String
  let isPlacementMode: Bool
  let onTogglePlacement: () -> Void
  let onSelectMarker: (Int) -> Void
  let onDeleteMarker: (Int) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      HStack(spacing: Spacing.sm) {
        Button(action: onTogglePlacement) {
          Label(
            L10n.string("media.summary.marker.toggle"),
            systemImage: isPlacementMode ? "mappin.circle.fill" : "mappin.circle"
          )
          .font(Typography.callout.weight(.semibold))
        }
        .buttonStyle(.glass)
        .tint(isPlacementMode ? AuthorPalette.color(fromHex: authorColorHex) : nil)

        Spacer()
      }

      if isPlacementMode {
        Text(L10n.string("media.summary.marker.hint"))
          .font(Typography.footnote)
          .foregroundStyle(.secondary)
      }

      if !markers.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: Spacing.xs) {
            ForEach(markers) { marker in
              markerChip(marker)
            }
          }
        }
      }
    }
  }

  private func markerChip(_ marker: SummaryDraftMarker) -> some View {
    let isSelected = selectedMarkerNumber == marker.number
    let color = AuthorPalette.color(fromHex: authorColorHex)
    return HStack(spacing: Spacing.xxs) {
      Button {
        onSelectMarker(marker.number)
      } label: {
        Text("[\(marker.number)]")
          .font(Typography.markerNumber)
          .foregroundStyle(color)
      }
      .buttonStyle(.plain)

      Button {
        onDeleteMarker(marker.number)
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(Typography.caption)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, Spacing.xs)
    .padding(.vertical, Spacing.xxs)
    .background(
      color.opacity(
        isSelected
          ? MediaSummaryConstants.selectedMarkerChipOpacity
          : MediaSummaryConstants.markerChipBackgroundOpacity
      ),
      in: .capsule
    )
  }
}
