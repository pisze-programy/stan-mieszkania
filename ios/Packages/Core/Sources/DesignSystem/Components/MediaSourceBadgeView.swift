import Domain
import SwiftUI

public struct MediaSourceBadgeView: View {
  private let source: MediaSource
  private let capturedAtFromImport: Bool
  private let compact: Bool

  public init(
    source: MediaSource,
    capturedAtFromImport: Bool = false,
    compact: Bool = false
  ) {
    self.source = source
    self.capturedAtFromImport = capturedAtFromImport
    self.compact = compact
  }

  public var body: some View {
    HStack(spacing: Spacing.xxs) {
      Image(systemName: symbolName)
        .font(Typography.caption)
      if !compact {
        Text(labelText)
          .font(Typography.caption)
      }
    }
    .foregroundStyle(.secondary)
    .accessibilityLabel(labelText)
  }

  private var symbolName: String {
    switch source {
    case .camera:
      return "camera.fill"
    case .imported:
      return "photo.on.rectangle"
    }
  }

  private var labelText: String {
    switch source {
    case .camera:
      return L10n.string("media.detail.source.camera")
    case .imported:
      if capturedAtFromImport {
        return L10n.string("media.detail.source.import.no.exif")
      }
      return L10n.string("media.detail.source.import")
    }
  }
}
