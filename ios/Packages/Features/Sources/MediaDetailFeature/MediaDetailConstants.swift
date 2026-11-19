import CoreFoundation
import Foundation

enum MediaDetailConstants {
  static let photoMaxPixelSize: Int = 2_000
  static let imageRenderScale: CGFloat = 1
  static let photoMaxHeight: CGFloat = 340
  private static let fallbackAspectWidth: CGFloat = 4
  private static let fallbackAspectHeight: CGFloat = 3
  static let fallbackPhotoAspectRatio: CGFloat = fallbackAspectWidth / fallbackAspectHeight
  static let composerLineMin: Int = 2
  static let composerLineMax: Int = 5
  static let placeholderBackgroundOpacity: Double = 0.1
  static let tombstoneBackgroundOpacity: Double = 0.12
  static let highlightedBorderOpacity: Double = 0.65
  static let markerChipOpacity: Double = 0.14
  static let selectedMarkerChipOpacity: Double = 0.28
  static let unknownErrorCode: String = "MEDIA_DETAIL_ERROR"
}
