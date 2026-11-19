import DesignSystem
import SwiftUI

struct MediaLightboxCaptionCard: View {
  let caption: LightboxMarkerCaption
  let referenceDate: Date
  let onSelectMarker: (Int) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.xxs) {
      HighlightedEntryTextView(
        text: caption.entryText,
        selectedMarkerNumber: caption.markerNumber,
        linkedMarkerNumbers: caption.linkedMarkerNumbers,
        onMarkerTapped: onSelectMarker
      )
      .frame(maxWidth: .infinity, alignment: .leading)

      Text(caption.formattedAuthorLine(referenceDate: referenceDate))
        .font(Typography.caption)
        .foregroundStyle(.secondary)
    }
    .padding(Spacing.sm)
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassEffect(.regular, in: .rect(cornerRadius: CornerRadius.md, style: .continuous))
  }
}
