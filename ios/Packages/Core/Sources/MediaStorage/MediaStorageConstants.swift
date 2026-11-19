import Foundation

public enum MediaStorageConstants: Sendable {
  public static let jpegFileExtension: String = "jpg"
  public static let defaultCacheFolderName: String = "MediaCache"
  public static let minCompressionQuality: Double = 0.25
  public static let qualityStepDecrement: Double = 0.1
  public static let maxCompressionAttempts: Int = 8
  public static let exifDateFormat: String = "yyyy:MM:dd HH:mm:ss"
  public static let posixLocaleIdentifier: String = "en_US_POSIX"
  public static let gpsSouthRef: String = "S"
  public static let gpsWestRef: String = "W"
  public static let hexByteFormat: String = "%02x"
  public static let cgOrientationUp: Int = 1
  public static let firstImageIndex: Int = 0
  public static let singleImageCount: Int = 1
  public static let utcTimeZoneIdentifier: String = "UTC"
  public static let secondsPerHour: Int = 3_600
  public static let secondsPerMinute: Int = 60
  public static let offsetPartsCount: Int = 2
  public static let negativeSign: Character = "-"
  public static let positiveSign: Character = "+"
  public static let zuluTimeMarker: String = "Z"
  public static let offsetSeparator: Character = ":"
  public static let minQualityExclusive: Double = 0.0
  public static let maxQualityInclusive: Double = 1.0
}
