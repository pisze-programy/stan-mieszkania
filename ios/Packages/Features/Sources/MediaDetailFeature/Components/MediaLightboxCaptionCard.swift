import DesignSystem
import Domain
import SwiftUI

struct MediaLightboxCaptionCard: View {
  let caption: LightboxMarkerCaption
  let referenceDate: Date
  let onSelectMarker: (Int) -> Void

  var body: some View {
    let formattedDate = PolishDateFormatters.formatHumanTimestamp(
      caption.createdAt,
      now: referenceDate
    )
    let authorLine: String
    if let shortTag = caption.authorShortTag, !shortTag.isEmpty {
      authorLine = "\(caption.authorDisplayName) #\(shortTag) · \(formattedDate)"
    } else {
      authorLine = "\(caption.authorDisplayName) · \(formattedDate)"
    }
    return VStack(alignment: .leading, spacing: Spacing.xxs) {
      HighlightedEntryTextView(
        text: caption.entryText,
        selectedMarkerNumber: caption.markerNumber,
        onMarkerTapped: onSelectMarker
      )
      .frame(maxWidth: .infinity, alignment: .leading)

      Text(authorLine)
        .font(Typography.caption)
        .foregroundStyle(.secondary)
    }
    .padding(Spacing.sm)
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassEffect(.regular, in: .rect(cornerRadius: CornerRadius.md, style: .continuous))
  }
}
