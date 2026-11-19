import DesignSystem
import Domain
import SwiftUI

struct DetailMetadataSheetView: View {
  let media: MediaItem
  let onClose: () -> Void

  // Decision Q10 & S2-12: Show source, capture/cloud timestamps, and SHA-256; never display GPS.
  var body: some View {
    NavigationStack {
      List {
        Section {
          HStack {
            MediaSourceBadgeView(
              source: media.source,
              capturedAtFromImport: media.capturedAtFromImport
            )
            Spacer()
            SyncStatusIndicatorView(
              syncState: media.syncState,
              isVerified: media.isVerified,
              compact: false
            )
          }

          Text(
            L10n.format(
              "media.detail.timestamp.captured",
              PolishDateFormatters.formatTimestamp(media.capturedAt)
            )
          )
          .font(Typography.callout)

          if let serverReceivedAt = media.serverReceivedAt {
            Text(
              L10n.format(
                "media.detail.timestamp.cloud",
                PolishDateFormatters.formatTimestamp(serverReceivedAt)
              )
            )
            .font(Typography.callout)
          }
        }

        Section {
          Text(L10n.format("media.detail.sha256", media.sha256))
            .font(Typography.caption.monospaced())
            .textSelection(.enabled)
        }
      }
      .navigationTitle(L10n.string("media.detail.metadata.title"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.string("apartment.history.close.cta"), action: onClose)
        }
      }
    }
  }
}
