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
    GlassCard(cornerRadius: CornerRadius.md, padding: Spacing.sm) {
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

        if composer.isMarkerPlacementMode {
          Text(L10n.string("media.summary.marker.hint"))
            .font(Typography.footnote)
            .foregroundStyle(.secondary)
        }

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
        .glassEffect(.regular, in: .rect(cornerRadius: CornerRadius.sm))

        if let errorMessage = composer.errorMessage {
          Text(errorMessage)
            .font(Typography.footnote)
            .foregroundStyle(.red)
        }

        HStack(spacing: Spacing.sm) {
          GlassActionButton(
            title: L10n.string("apartments.create.cancel.cta"),
            variant: .secondary,
            isDisabled: composer.isSubmitting,
            action: onCancel
          )
          GlassActionButton(
            title: L10n.string("apartment.edit.save.cta"),
            variant: .primary,
            isLoading: composer.isSubmitting,
            action: onSubmit
          )
        }
      }
    }
  }

  private func markerChip(_ marker: DetailDraftMarker) -> some View {
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
          ? MediaDetailConstants.selectedMarkerChipOpacity
          : MediaDetailConstants.markerChipOpacity
      ),
      in: .capsule
    )
  }
}
