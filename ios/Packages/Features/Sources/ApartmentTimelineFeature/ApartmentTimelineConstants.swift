import CoreFoundation
import Foundation

enum ApartmentTimelineConstants {
  private static let quotaToastAutoDismissSeconds: Int = 4

  static let gridColumnCount: Int = 3
  static let thumbnailMaxPixelSize: Int = 400
  static let imageRenderScale: CGFloat = 1
  static let tombstoneBackgroundOpacity: Double = 0.12
  static let placeholderBackgroundOpacity: Double = 0.1
  static let shareHighlightOpacity: Double = 0.2
  static let quotaBadgeLineLimit: Int = 1
  static let tombstoneLineLimit: Int = 2
  static let cloudStatusMinWidth: CGFloat = 64
  static let quotaPopoverMaxWidth: CGFloat = 260
  static let dayHeaderVerticalPadding: CGFloat = 6
  static let loadingPlaceholderHeight: CGFloat = 1
  static let quotaToastAutoDismissDelay: Duration = .seconds(quotaToastAutoDismissSeconds)
  static let editSheetID: String = "edit-apartment"
  static let historySheetID: String = "apartment-history"
  static let zoomTransitionSourcePrefix: String = "timeline-media-"
  static let unknownErrorCode: String = "APARTMENT_TIMELINE_ERROR"
}
