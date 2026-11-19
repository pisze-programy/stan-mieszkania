import CoreFoundation
import Foundation

public enum CaptureConstants: Sendable {
  public static let locationTimeoutSeconds: Double = 2.5
  public static let authorizationTimeoutSeconds: Double = 15.0
  static let gpsPromptDismissedDefaultsKey: String = "stanmieszkania.capture.gpsPromptDismissed"
  static let jpegExportQuality: CGFloat = 1.0
  static let heroIconSize: CGFloat = 44
}
