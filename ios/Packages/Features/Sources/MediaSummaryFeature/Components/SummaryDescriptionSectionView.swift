import DesignSystem
import SwiftUI

struct SummaryDescriptionSectionView: View {
  let description: String
  let markers: [SummaryDraftMarker]
  let selectedMarkerNumber: Int?
  let authorColorHex: String
  let isInteractive: Bool
  let isFocused: FocusState<Bool>.Binding
  let onDescriptionChanged: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      TextField(
        L10n.string("media.summary.description.placeholder"),
        text: Binding(
          get: { description },
          set: { newValue in
            guard isInteractive, newValue != description else {
              return
            }
            onDescriptionChanged(newValue)
          }
        ),
        axis: .vertical
      )
      .focused(isFocused)
      .disabled(!isInteractive)
      .lineLimit(
        MediaSummaryConstants
          .descriptionLineRangeMin...MediaSummaryConstants.descriptionLineRangeMax
      )
      .padding(Spacing.sm)
      .background(
        Surface.inset,
        in: .rect(cornerRadius: CornerRadius.field, style: .continuous)
      )

      if !description.isEmpty && !markers.isEmpty {
        SurfaceCard(cornerRadius: CornerRadius.md, padding: Spacing.sm) {
          HighlightedEntryTextView(
            text: description,
            selectedMarkerNumber: selectedMarkerNumber,
            authorColorHex: authorColorHex
          )
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }
}
