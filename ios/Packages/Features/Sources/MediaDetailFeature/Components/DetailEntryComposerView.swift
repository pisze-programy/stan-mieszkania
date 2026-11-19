import DesignSystem
import SwiftUI

struct DetailEntryComposerView: View {
  let composer: EntryComposerState
  let authorColorHex: String
  let selectedMarkerNumber: Int?
  let onTextChanged: (String) -> Void
  let onToggleMarkerMode: () -> Void
  let onSelectMarker: (Int) -> Void
  let onDeleteMarker: (Int) -> Void
  let onSubmit: () -> Void
  let onCancel: () -> Void

  var body: some View {
    SurfaceCard(cornerRadius: CornerRadius.md, padding: Spacing.sm) {
      VStack(alignment: .leading, spacing: Spacing.xs) {
        HStack {
          Button(action: onToggleMarkerMode) {
            Label(
              L10n.string("media.summary.marker.toggle"),
              systemImage: composer.isMarkerPlacementMode ? "mappin.circle.fill" : "mappin.circle"
            )
            .font(Typography.callout.weight(.semibold))
          }
          .buttonStyle(.glass)
          .tint(composer.isMarkerPlacementMode ? AuthorPalette.color(fromHex: authorColorHex) : nil)
          Spacer()
        }

        StableSlot(minHeight: MediaDetailConstants.composerHintSlotHeight) {
          if composer.isMarkerPlacementMode {
            Text(L10n.string("media.summary.marker.hint"))
              .font(Typography.footnote)
              .foregroundStyle(.secondary)
          }
        }
        .animation(Motion.fade, value: composer.isMarkerPlacementMode)

        if !composer.markers.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
              ForEach(composer.markers) { marker in
                markerChip(marker)
              }
            }
          }
        }

        TextField(
          L10n.string("media.detail.entry.placeholder"),
          text: Binding(get: { composer.text }, set: { onTextChanged($0) }),
          axis: .vertical
        )
        .lineLimit(MediaDetailConstants.composerLineMin...MediaDetailConstants.composerLineMax)
        .padding(Spacing.xs)
        .background(
          Surface.inset,
          in: .rect(cornerRadius: CornerRadius.field, style: .continuous)
        )

        StableSlot(minHeight: MediaDetailConstants.composerErrorSlotHeight) {
          if let errorMessage = composer.errorMessage {
            Text(errorMessage)
              .font(Typography.footnote)
              .foregroundStyle(.red)
          }
        }
        .animation(Motion.fade, value: composer.errorMessage)

        HStack(spacing: Spacing.sm) {
          Button(L10n.string("apartments.create.cancel.cta"), action: onCancel)
            .buttonStyle(.borderless)
            .disabled(composer.isSubmitting)
          Spacer()
          GlassActionButton(
            title: L10n.string("apartment.edit.save.cta"),
            variant: .primary,
            isLoading: composer.isSubmitting,
            expandsHorizontally: false,
            controlSize: .regular,
            action: onSubmit
          )
        }
      }
    }
  }

  private func markerChip(_ marker: DetailDraftMarker) -> some View {
    let isSelected = selectedMarkerNumber == marker.number
    let color = MarkerPalette.color(forMarkerNumber: marker.number)
    return HStack(spacing: 0) {
      Button {
        onSelectMarker(marker.number)
      } label: {
        HStack(spacing: MediaDetailConstants.markerChipSpacing) {
          Circle()
            .fill(color)
            .frame(
              width: MediaDetailConstants.markerChipDotSize,
              height: MediaDetailConstants.markerChipDotSize
            )
          Text("\(marker.number)")
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, MediaDetailConstants.markerChipVerticalPadding)
      }
      .buttonStyle(.plain)

      if composer.isMarkerPlacementMode {
        deleteMarkerButton(for: marker.number)
      }
    }
    .background(
      color.opacity(
        isSelected
          ? MediaDetailConstants.selectedMarkerChipOpacity
          : MediaDetailConstants.markerChipBackgroundOpacity
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
