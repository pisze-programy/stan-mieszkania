import CoreFoundation
import Foundation

enum MediaSummaryConstants {
  static let previewMaxPixelSize: Int = 1_600
  static let imageRenderScale: CGFloat = 1
  static let photoMaxHeight: CGFloat = 340
  private static let fallbackAspectWidth: CGFloat = 4
  private static let fallbackAspectHeight: CGFloat = 3
  static let fallbackPhotoAspectRatio: CGFloat = fallbackAspectWidth / fallbackAspectHeight
  static let descriptionLineRangeMin: Int = 3
  static let descriptionLineRangeMax: Int = 6
  static let placeholderBackgroundOpacity: Double = 0.1
  static let markerChipBackgroundOpacity: Double = 0.14
  static let selectedMarkerChipOpacity: Double = 0.28
  static let unknownErrorCode: String = "MEDIA_SUMMARY_ERROR"
}
