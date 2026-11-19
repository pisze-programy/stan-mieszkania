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

      StableSlot(minHeight: MediaSummaryConstants.markerHintSlotHeight) {
        if isPlacementMode {
          Text(L10n.string("media.summary.marker.hint"))
            .font(Typography.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .animation(Motion.fade, value: isPlacementMode)

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
    let color = MarkerPalette.color(forMarkerNumber: marker.number)
    return HStack(spacing: 0) {
      Button {
        onSelectMarker(marker.number)
      } label: {
        HStack(spacing: MediaSummaryConstants.markerChipSpacing) {
          Circle()
            .fill(color)
            .frame(
              width: MediaSummaryConstants.markerChipDotSize,
              height: MediaSummaryConstants.markerChipDotSize
            )
          Text("\(marker.number)")
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, MediaSummaryConstants.markerChipVerticalPadding)
      }
      .buttonStyle(.plain)

      if isPlacementMode {
        deleteMarkerButton(for: marker.number)
      }
    }
    .background(
      color.opacity(
        isSelected
          ? MediaSummaryConstants.selectedMarkerChipOpacity
          : MediaSummaryConstants.markerChipBackgroundOpacity
      ),
      in: .capsule
    )
    .contextMenu {
      Button(role: .destructive) {
        onDeleteMarker(marker.number)
      } label: {
        Label(
          L10n.format("media.summary.marker.delete", marker.number),
          systemImage: "trash"
        )
      }
    }
  }

  private func deleteMarkerButton(for number: Int) -> some View {
    Button {
      onDeleteMarker(number)
    } label: {
      Image(systemName: "xmark")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(
          width: DesignMetrics.markerHitTargetSize,
          height: DesignMetrics.markerHitTargetSize
        )
        .contentShape(.circle)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(L10n.format("media.summary.marker.delete", number))
  }
}
