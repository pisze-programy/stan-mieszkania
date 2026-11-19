import Domain
import Foundation
import ImageIO

struct CapturedMetadataResult: Sendable, Equatable {
  let capturedAt: Date
  let capturedTz: String
  let capturedAtFromImport: Bool
  let location: CaptureLocationMetadata?
}

enum PhotoMetadataExtractor: Sendable {
  static func extractCaptureMetadata(
    from properties: [CFString: Any],
    request: PhotoIngestRequest
  ) -> CapturedMetadataResult {
    let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
    let offsetRaw = (exif?[kCGImagePropertyExifOffsetTimeOriginal] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedOffset = offsetRaw?.isEmpty == false ? offsetRaw : nil
    let timeZone = resolveTimeZone(
      offsetString: resolvedOffset,
      fallbackIdentifier: request.timeZoneIdentifier
    )
    let capturedTz = resolvedOffset ?? nonEmptyTimeZoneIdentifier(request.timeZoneIdentifier)

    let exifDate: Date?
    if let dateString = exif?[kCGImagePropertyExifDateTimeOriginal] as? String {
      exifDate = parseExifDate(dateString, timeZone: timeZone)
    } else {
      exifDate = nil
    }

    // Decision S2-12: Imported photos without EXIF DateTimeOriginal fall back to import time and flag it.
    let capturedAt: Date
    let capturedAtFromImport: Bool
    switch request.source {
    case .camera:
      capturedAt = exifDate ?? request.now
      capturedAtFromImport = false
    case .imported:
      if let exifDate {
        capturedAt = exifDate
        capturedAtFromImport = false
      } else {
        capturedAt = request.now
        capturedAtFromImport = true
      }
    }

    // Decision Q10: Prefer explicit device location; otherwise fall back to EXIF {GPS} metadata.
    let location = request.deviceLocation ?? extractExifLocation(from: properties)
    return CapturedMetadataResult(
      capturedAt: capturedAt,
      capturedTz: capturedTz,
      capturedAtFromImport: capturedAtFromImport,
      location: location
    )
  }

  static func buildPreservedMetadata(
    from properties: [CFString: Any],
    pixelWidth: Int,
    pixelHeight: Int
  ) -> [CFString: Any] {
    var output: [CFString: Any] = [
      kCGImagePropertyOrientation: MediaStorageConstants.cgOrientationUp
    ]

    if var exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
      exif[kCGImagePropertyExifPixelXDimension] = pixelWidth
      exif[kCGImagePropertyExifPixelYDimension] = pixelHeight
      output[kCGImagePropertyExifDictionary] = exif
    }

    if var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
      tiff[kCGImagePropertyTIFFOrientation] = MediaStorageConstants.cgOrientationUp
      output[kCGImagePropertyTIFFDictionary] = tiff
    }

    if let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
      output[kCGImagePropertyGPSDictionary] = gps
    }

    return output
  }

  private static func extractExifLocation(
    from properties: [CFString: Any]
  ) -> CaptureLocationMetadata? {
    guard let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] else {
      return nil
    }
    guard
      let rawLat = numericValue(gps[kCGImagePropertyGPSLatitude]),
      let rawLng = numericValue(gps[kCGImagePropertyGPSLongitude])
    else {
      return nil
    }

    let latRef = (gps[kCGImagePropertyGPSLatitudeRef] as? String)?.uppercased()
    let lngRef = (gps[kCGImagePropertyGPSLongitudeRef] as? String)?.uppercased()
    let lat = latRef == MediaStorageConstants.gpsSouthRef ? -abs(rawLat) : rawLat
    let lng = lngRef == MediaStorageConstants.gpsWestRef ? -abs(rawLng) : rawLng
    let accuracyM = numericValue(gps[kCGImagePropertyGPSHPositioningError])

    return CaptureLocationMetadata(
      lat: lat,
      lng: lng,
      accuracyM: accuracyM,
      locationSource: .exif
    )
  }

  private static func numericValue(_ raw: Any?) -> Double? {
    if let number = raw as? NSNumber {
      return number.doubleValue
    }
    if let doubleValue = raw as? Double {
      return doubleValue
    }
    return nil
  }

  private static func parseExifDate(_ value: String, timeZone: TimeZone) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: MediaStorageConstants.posixLocaleIdentifier)
    formatter.timeZone = timeZone
    formatter.dateFormat = MediaStorageConstants.exifDateFormat
    return formatter.date(from: value)
  }

  private static func resolveTimeZone(
    offsetString: String?,
    fallbackIdentifier: String
  ) -> TimeZone {
    if let offsetString, let parsed = parseOffsetTimeZone(offsetString) {
      return parsed
    }
    return TimeZone(identifier: fallbackIdentifier)
      ?? TimeZone(secondsFromGMT: 0)
      ?? TimeZone.current
  }

  private static func parseOffsetTimeZone(_ value: String) -> TimeZone? {
    if value.uppercased() == MediaStorageConstants.zuluTimeMarker {
      return TimeZone(secondsFromGMT: 0)
    }
    guard let first = value.first else {
      return nil
    }
    let sign: Int
    if first == MediaStorageConstants.negativeSign {
      sign = -1
    } else if first == MediaStorageConstants.positiveSign {
      sign = 1
    } else {
      return nil
    }

    let parts = value.dropFirst().split(separator: MediaStorageConstants.offsetSeparator)
    guard
      parts.count == MediaStorageConstants.offsetPartsCount,
      let hours = Int(parts[0]),
      let minutes = Int(parts[1])
    else {
      return nil
    }
    let seconds =
      sign
      * (hours * MediaStorageConstants.secondsPerHour
        + minutes * MediaStorageConstants.secondsPerMinute)
    return TimeZone(secondsFromGMT: seconds)
  }

  private static func nonEmptyTimeZoneIdentifier(_ identifier: String) -> String {
    let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? MediaStorageConstants.utcTimeZoneIdentifier : trimmed
  }
}
