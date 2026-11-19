import CoreFoundation
import Foundation

enum MediaSummaryConstants {
  static let previewMaxPixelSize: Int = 1_600
  static let imageRenderScale: CGFloat = 1
  static let photoHeightRatio: CGFloat = 0.45
  static let photoMaxHeightCap: CGFloat = 420
  static let pagerButtonHitSize: CGFloat = 36
  private static let fallbackAspectWidth: CGFloat = 4
  private static let fallbackAspectHeight: CGFloat = 3
  static let fallbackPhotoAspectRatio: CGFloat = fallbackAspectWidth / fallbackAspectHeight
  static let descriptionLineRangeMin: Int = 3
  static let descriptionLineRangeMax: Int = 6
  static let placeholderBackgroundOpacity: Double = 0.1
  static let markerHintSlotHeight: CGFloat = 18
  static let markerChipDotSize: CGFloat = 8
  static let markerChipSpacing: CGFloat = 6
  static let markerChipVerticalPadding: CGFloat = 6
  static let markerChipBackgroundOpacity: Double = 0.12
  static let selectedMarkerChipOpacity: Double = 0.22
  static let unknownErrorCode: String = "MEDIA_SUMMARY_ERROR"
}
