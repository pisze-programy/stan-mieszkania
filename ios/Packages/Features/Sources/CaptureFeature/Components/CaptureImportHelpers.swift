import DesignSystem
import Foundation
import PhotosUI
import SwiftUI

struct CaptureProcessingHUDView: View {
  var body: some View {
    VStack(spacing: CaptureConstants.hudSpacing) {
      ProgressView()
        .controlSize(.large)
      Text(L10n.string("capture.processing.hud"))
        .font(Typography.callout)
    }
    .padding(CaptureConstants.hudPadding)
    .glassEffect(
      .regular,
      in: .rect(cornerRadius: CaptureConstants.hudCornerRadius, style: .continuous)
    )
  }
}

enum CaptureImportHelpers {
  static func loadTransferableData(from items: [PhotosPickerItem]) async -> [Data] {
    var rawDataList: [Data] = []
    rawDataList.reserveCapacity(items.count)
    for item in items {
      if let data = try? await item.loadTransferable(type: Data.self) {
        rawDataList.append(data)
      }
    }
    return rawDataList
  }

  static func readSecurityScopedData(from urls: [URL]) -> [Data] {
    var rawDataList: [Data] = []
    rawDataList.reserveCapacity(urls.count)
    for url in urls {
      let didAccess = url.startAccessingSecurityScopedResource()
      defer {
        if didAccess {
          url.stopAccessingSecurityScopedResource()
        }
      }
      if let data = try? Data(contentsOf: url) {
        rawDataList.append(data)
      }
    }
    return rawDataList
  }
}
