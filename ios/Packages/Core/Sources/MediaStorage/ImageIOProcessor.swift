import CoreGraphics
import Domain
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ProcessedPhotoBytes: Sendable {
  let jpegData: Data
  let width: Int
  let height: Int
  let metadata: CapturedMetadataResult
}

enum ImageIOProcessor: Sendable {
  static func processPhoto(request: PhotoIngestRequest) throws -> ProcessedPhotoBytes {
    try validateCompression(request.compression)

    guard let source = CGImageSourceCreateWithData(request.rawData as CFData, nil) else {
      throw MediaStorageError.invalidImageData
    }
    let sourceProperties =
      CGImageSourceCopyPropertiesAtIndex(
        source,
        MediaStorageConstants.firstImageIndex,
        nil
      ) as? [CFString: Any] ?? [:]

    let metadata = PhotoMetadataExtractor.extractCaptureMetadata(
      from: sourceProperties,
      request: request
    )
    let cgImage = try decodeScaledImage(
      from: source,
      sourceProperties: sourceProperties,
      maxDimensionPx: request.compression.maxDimensionPx
    )
    let preservedMetadata = PhotoMetadataExtractor.buildPreservedMetadata(
      from: sourceProperties,
      pixelWidth: cgImage.width,
      pixelHeight: cgImage.height
    )
    let jpegData = try encodeWithinMaxBytes(
      cgImage: cgImage,
      preservedMetadata: preservedMetadata,
      compression: request.compression
    )

    return ProcessedPhotoBytes(
      jpegData: jpegData,
      width: cgImage.width,
      height: cgImage.height,
      metadata: metadata
    )
  }

  // Decision S2-10: Downsample disk images directly via ImageIO without full-resolution decode.
  static func loadDownsampledThumbnail(
    from fileURL: URL,
    mediaId: String,
    maxPixelSize: Int
  ) throws -> CGImage {
    guard maxPixelSize > 0 else {
      throw MediaStorageError.invalidConfiguration("maxPixelSize must be positive")
    }
    guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
      throw MediaStorageError.thumbnailGenerationFailed(mediaId: mediaId)
    }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
    ]
    guard
      let thumbnail = CGImageSourceCreateThumbnailAtIndex(
        source,
        MediaStorageConstants.firstImageIndex,
        options as CFDictionary
      )
    else {
      throw MediaStorageError.thumbnailGenerationFailed(mediaId: mediaId)
    }
    return thumbnail
  }

  private static func validateCompression(_ compression: JpegCompressionSettings) throws {
    guard compression.maxDimensionPx > 0 else {
      throw MediaStorageError.invalidConfiguration("maxDimensionPx must be positive")
    }
    guard compression.maxBytes > 0 else {
      throw MediaStorageError.invalidConfiguration("maxBytes must be positive")
    }
    guard
      compression.quality > MediaStorageConstants.minQualityExclusive,
      compression.quality <= MediaStorageConstants.maxQualityInclusive
    else {
      throw MediaStorageError.invalidConfiguration("quality must be in (0, 1]")
    }
  }

  private static func decodeScaledImage(
    from source: CGImageSource,
    sourceProperties: [CFString: Any],
    maxDimensionPx: Int
  ) throws -> CGImage {
    let pixelWidth = (sourceProperties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
    let pixelHeight = (sourceProperties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
    let sourceMax = max(pixelWidth, pixelHeight)
    let targetMax = sourceMax > 0 ? min(sourceMax, maxDimensionPx) : maxDimensionPx

    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: targetMax,
    ]
    guard
      let image = CGImageSourceCreateThumbnailAtIndex(
        source,
        MediaStorageConstants.firstImageIndex,
        options as CFDictionary
      )
    else {
      throw MediaStorageError.invalidImageData
    }
    return image
  }

  private static func encodeWithinMaxBytes(
    cgImage: CGImage,
    preservedMetadata: [CFString: Any],
    compression: JpegCompressionSettings
  ) throws -> Data {
    let opaqueImage = OpaqueImageConverter.makeOpaqueIfNeeded(cgImage)
    var quality = compression.quality
    var lastData = try encodeJpeg(
      cgImage: opaqueImage,
      metadata: preservedMetadata,
      quality: quality
    )

    for _ in 0..<MediaStorageConstants.maxCompressionAttempts {
      if lastData.count <= compression.maxBytes {
        return lastData
      }
      if quality <= MediaStorageConstants.minCompressionQuality {
        break
      }
      quality = max(
        MediaStorageConstants.minCompressionQuality,
        quality - MediaStorageConstants.qualityStepDecrement
      )
      lastData = try encodeJpeg(
        cgImage: opaqueImage,
        metadata: preservedMetadata,
        quality: quality
      )
    }

    guard lastData.count <= compression.maxBytes else {
      throw MediaStorageError.exceedsMaxBytes(
        actualBytes: lastData.count,
        maxBytes: compression.maxBytes
      )
    }
    return lastData
  }

  private static func encodeJpeg(
    cgImage: CGImage,
    metadata: [CFString: Any],
    quality: Double
  ) throws -> Data {
    let mutableData = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        mutableData as CFMutableData,
        UTType.jpeg.identifier as CFString,
        MediaStorageConstants.singleImageCount,
        nil
      )
    else {
      throw MediaStorageError.encodingFailed
    }

    var options = metadata
    options[kCGImageDestinationLossyCompressionQuality] = quality
    CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      throw MediaStorageError.encodingFailed
    }
    return mutableData as Data
  }
}
