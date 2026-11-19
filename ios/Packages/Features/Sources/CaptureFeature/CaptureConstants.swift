import CoreFoundation
import Foundation

public enum CaptureConstants: Sendable {
  public static let locationTimeoutSeconds: Double = 2.5
  public static let authorizationTimeoutSeconds: Double = 15.0
  private static let presentationSettleMilliseconds: Int = 450
  public static let presentationSettleDelay: Duration = .milliseconds(
    presentationSettleMilliseconds
  )
  public static let maxImportCount: Int = 20
  static let gpsPromptDismissedDefaultsKey: String = "stanmieszkania.capture.gpsPromptDismissed"
  static let jpegExportQuality: CGFloat = 1.0
  static let heroIconSize: CGFloat = 44
  static let hudCornerRadius: CGFloat = 24
  static let hudPadding: CGFloat = 24
  static let hudSpacing: CGFloat = 12
}
