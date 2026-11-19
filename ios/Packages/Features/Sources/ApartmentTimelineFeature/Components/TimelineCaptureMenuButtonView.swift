import DesignSystem
import Domain
import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

struct TimelineCaptureMenuButtonView: View {
  let isDisabled: Bool
  let onSelect: (CaptureSource) -> Void

  private static var isCameraAvailable: Bool {
    #if os(iOS)
      UIImagePickerController.isSourceTypeAvailable(.camera)
    #else
      false
    #endif
  }

  var body: some View {
    Menu {
      if Self.isCameraAvailable {
        Button {
          onSelect(.camera)
        } label: {
          Label(L10n.string("capture.menu.camera"), systemImage: "camera")
        }
      }
      Button {
        onSelect(.photoLibrary)
      } label: {
        Label(L10n.string("capture.menu.library"), systemImage: "photo.on.rectangle")
      }
      Button {
        onSelect(.files)
      } label: {
        Label(L10n.string("capture.menu.files"), systemImage: "folder")
      }
      // Decision MVP: Video capture is intentionally disabled with a coming-soon label.
      Section {
        Label(L10n.string("capture.menu.video.disabled"), systemImage: "video")
          .disabled(true)
      }
    } label: {
      Image(systemName: "plus")
        .font(.title2.weight(.semibold))
        .frame(
          width: DesignMetrics.floatingActionButtonSize,
          height: DesignMetrics.floatingActionButtonSize
        )
        .contentShape(.circle)
        .glassEffect(.regular.interactive(), in: .circle)
    }
    .menuOrder(.fixed)
    .disabled(isDisabled)
    .accessibilityLabel(L10n.string("capture.menu.camera"))
  }
}
