import CoreFoundation
import Foundation

enum MediaDetailConstants {
  static let photoMaxPixelSize: Int = 2_000
  static let lightboxMaxPixelSize: Int = 4_096
  static let imageRenderScale: CGFloat = 1
  static let defaultPhotoMaxHeight: CGFloat = 340
  static let photoMaxHeightRatio: CGFloat = 0.55
  static let photoMaxHeightCap: CGFloat = 520
  private static let fallbackAspectWidth: CGFloat = 4
  private static let fallbackAspectHeight: CGFloat = 3
  static let fallbackPhotoAspectRatio: CGFloat = fallbackAspectWidth / fallbackAspectHeight
  static let composerLineMin: Int = 2
  static let composerLineMax: Int = 5
  static let composerErrorSlotHeight: CGFloat = 18
  static let placeholderBackgroundOpacity: Double = 0.1
  static let tombstoneBackgroundOpacity: Double = 0.12
  static let eyeToggleSize: CGFloat = 36
  static let eyeTogglePadding: CGFloat = 10
  static let lightboxChromeZIndex: Double = 2
  static let lightboxDragMinimumDistance: CGFloat = 24
  static let lightboxDismissTranslation: CGFloat = 120
  static let lightboxDismissPredicted: CGFloat = 300
  static let lightboxDismissFadeDistance: CGFloat = 240
  static let lightboxMinBackdropOpacity: Double = 0.2
  static let lightboxZoomTolerance: CGFloat = 0.01
  static let unknownErrorCode: String = "MEDIA_DETAIL_ERROR"
}
