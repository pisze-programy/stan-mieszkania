import DesignSystem
import Domain
import SwiftUI

struct DetailMetadataSheetView: View {
  let media: MediaItem
  @State private var isVerifiedInfoPresented = false

  // Decision Q10 & S2-12: Show source, status, and capture/cloud timestamps; never display GPS or raw SHA-256.
  var body: some View {
    NavigationStack {
      List {
        Section {
          LabeledContent(L10n.string("media.detail.metadata.source.label")) {
            MediaSourceBadgeView(
              source: media.source,
              capturedAtFromImport: media.capturedAtFromImport
            )
          }

          LabeledContent(L10n.string("media.detail.metadata.status.label")) {
            SyncStatusIndicatorView(
              syncState: media.syncState,
              isVerified: media.isVerified,
              placement: .labeled,
              onVerifiedTap: { isVerifiedInfoPresented = true }
            )
          }

          LabeledContent(
            L10n.string("media.detail.metadata.captured.label"),
            value: PolishDateFormatters.formatPreciseTimestamp(media.capturedAt)
          )

          if let serverReceivedAt = media.serverReceivedAt {
            LabeledContent(
              L10n.string("media.detail.metadata.cloud.label"),
              value: PolishDateFormatters.formatPreciseTimestamp(serverReceivedAt)
            )
          }
        }
      }
      .navigationTitle(L10n.string("media.detail.metadata.title"))
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .sheet(isPresented: $isVerifiedInfoPresented) {
        VerifiedInfoSheetView()
      }
    }
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
  }
}
