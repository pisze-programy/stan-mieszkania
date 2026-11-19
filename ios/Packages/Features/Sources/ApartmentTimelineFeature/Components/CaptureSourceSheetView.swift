import DesignSystem
import SwiftUI

struct CaptureSourceSheetView: View {
  let onSelect: (CaptureSource) -> Void
  let onCancel: () -> Void

  var body: some View {
    NavigationStack {
      List {
        Button {
          onSelect(.camera)
        } label: {
          Label(L10n.string("apartment.timeline.capture.camera"), systemImage: "camera")
        }

        Button {
          onSelect(.photoLibrary)
        } label: {
          Label(
            L10n.string("apartment.timeline.capture.gallery"),
            systemImage: "photo.on.rectangle"
          )
        }

        Button {
          onSelect(.files)
        } label: {
          Label(L10n.string("apartment.timeline.capture.files"), systemImage: "folder")
        }

        // Decision MVP: Video capture is visibly listed as coming soon and disabled.
        HStack {
          Label(
            videoDisabledTitle,
            systemImage: "video.slash"
          )
          Spacer()
        }
        .foregroundStyle(.secondary)
        .opacity(DesignMetrics.disabledOpacity)
        .disabled(true)
      }
      .navigationTitle(L10n.string("apartment.timeline.capture.sheet.title"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.string("apartments.create.cancel.cta"), action: onCancel)
        }
      }
    }
  }

  private var videoDisabledTitle: String {
    let video = L10n.string("apartment.timeline.capture.video")
    let suffix = L10n.string("apartment.timeline.capture.video.disabled")
      .lowercased(with: L10n.polishLocale)
    return "\(video) — \(suffix)"
  }
}
