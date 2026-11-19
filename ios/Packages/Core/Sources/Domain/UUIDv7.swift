import Foundation

public enum UUIDv7Error: Error, Equatable, Sendable {
  case timestampOutOfRange(Int64)
  case invalidRandomBytesCount(Int)
}

public protocol IDGenerator: Sendable {
  func generate() -> String
}

public struct SystemIDGenerator: IDGenerator, Sendable {
  public init() {}

  public func generate() -> String {
    UUIDv7.generateNow()
  }
}

public struct ClosureIDGenerator: IDGenerator, Sendable {
  private let handler: @Sendable () -> String

  public init(_ handler: @escaping @Sendable () -> String) {
    self.handler = handler
  }

  public func generate() -> String {
    handler()
  }
}

public enum UUIDv7: Sendable {
  private static let bitsPerUInt64: Int = 64
  private static let bitsPerByte: Int = 8

  public static func generate(
    timestampMs: Int64 = currentTimestampMs(),
    randomBytes: [UInt8]? = nil
  ) throws(UUIDv7Error) -> String {
    guard
      timestampMs >= DomainConstants.UUIDv7.minTimestampMs,
      timestampMs <= DomainConstants.UUIDv7.maxTimestampMs
    else {
      throw .timestampOutOfRange(timestampMs)
    }

    var bytes: [UInt8]
    if let randomBytes {
      guard randomBytes.count == DomainConstants.UUIDv7.byteCount else {
        throw .invalidRandomBytesCount(randomBytes.count)
      }
      bytes = randomBytes
    } else {
      bytes = generateRandomBytes()
    }

    // Decision Q6/A16: Client-generated RFC 9562 UUIDv7 encodes 48-bit Unix ms timestamp big-endian.
    for index in 0..<DomainConstants.UUIDv7.timestampByteCount {
      let shift = DomainConstants.UUIDv7.timestampByteShifts[index]
      let shifted = (timestampMs >> shift) & DomainConstants.UUIDv7.byteMask
      bytes[index] = UInt8(shifted)
    }

    let versionIndex = DomainConstants.UUIDv7.versionByteIndex
    bytes[versionIndex] =
      (bytes[versionIndex] & DomainConstants.UUIDv7.versionClearMask)
      | DomainConstants.UUIDv7.version7Nibble

    let variantIndex = DomainConstants.UUIDv7.variantByteIndex
    bytes[variantIndex] =
      (bytes[variantIndex] & DomainConstants.UUIDv7.variantClearMask)
      | DomainConstants.UUIDv7.variantRfcNibble

    return formatCanonical(bytes)
  }

  public static func generateNow() -> String {
    let clamped = min(
      max(currentTimestampMs(), DomainConstants.UUIDv7.minTimestampMs),
      DomainConstants.UUIDv7.maxTimestampMs
    )
    do {
      return try generate(timestampMs: clamped)
    } catch {
      return UUID().uuidString.lowercased()
    }
  }

  public static func isValid(_ value: String) -> Bool {
    guard value.count == DomainConstants.UUIDv7.canonicalLength else {
      return false
    }
    return value.range(of: DomainConstants.UUIDv7.validPattern, options: .regularExpression) != nil
  }

  public static func currentTimestampMs(date: Date = Date()) -> Int64 {
    Int64(date.timeIntervalSince1970 * DomainConstants.UUIDv7.millisecondsPerSecond)
  }

  private static func generateRandomBytes() -> [UInt8] {
    var generator = SystemRandomNumberGenerator()
    var result: [UInt8] = []
    result.reserveCapacity(DomainConstants.UUIDv7.byteCount)

    let chunks = DomainConstants.UUIDv7.byteCount / (bitsPerUInt64 / bitsPerByte)
    for _ in 0..<chunks {
      var value = generator.next()
      for _ in 0..<(bitsPerUInt64 / bitsPerByte) {
        result.append(UInt8(truncatingIfNeeded: value))
        value >>= bitsPerByte
      }
    }
    return result
  }

  private static func formatCanonical(_ bytes: [UInt8]) -> String {
    let groups = DomainConstants.UUIDv7.groupByteRanges.map { range in
      bytes[range]
        .map { String(format: DomainConstants.UUIDv7.hexFormat, $0) }
        .joined()
    }
    return groups.joined(separator: DomainConstants.UUIDv7.hyphenSeparator)
  }
}
