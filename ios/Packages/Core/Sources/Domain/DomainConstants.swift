import Foundation

public enum DomainConstants: Sendable {
  public enum UUIDv7: Sendable {
    public static let byteCount: Int = 16
    public static let canonicalLength: Int = 36
    public static let minTimestampMs: Int64 = 0
    public static let maxTimestampMs: Int64 = 0xFFFF_FFFF_FFFF
    public static let millisecondsPerSecond: Double = 1_000
    public static let timestampByteCount: Int = 6
    public static let byteMask: Int64 = 0xFF
    public static let versionByteIndex: Int = 6
    public static let variantByteIndex: Int = 8
    public static let versionClearMask: UInt8 = 0x0F
    public static let version7Nibble: UInt8 = 0x70
    public static let variantClearMask: UInt8 = 0x3F
    public static let variantRfcNibble: UInt8 = 0x80
    public static let hexFormat: String = "%02x"
    public static let hyphenSeparator: String = "-"
    public static let validPattern: String =
      #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-7[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"#

    private static let shiftByte0: Int = 40
    private static let shiftByte1: Int = 32
    private static let shiftByte2: Int = 24
    private static let shiftByte3: Int = 16
    private static let shiftByte4: Int = 8
    private static let shiftByte5: Int = 0
    public static let timestampByteShifts: [Int] = [
      shiftByte0,
      shiftByte1,
      shiftByte2,
      shiftByte3,
      shiftByte4,
      shiftByte5,
    ]

    private static let timeLowEnd: Int = 4
    private static let timeMidEnd: Int = 6
    private static let timeHiEnd: Int = 8
    private static let clockSeqEnd: Int = 10
    public static let groupByteRanges: [Range<Int>] = [
      0..<timeLowEnd,
      timeLowEnd..<timeMidEnd,
      timeMidEnd..<timeHiEnd,
      timeHiEnd..<clockSeqEnd,
      clockSeqEnd..<byteCount,
    ]
  }

  public static let shortTagLength: Int = 4
  public static let firstMarkerNumber: Int = 1
  public static let defaultAuthorColor: String = "#007AFF"
  public static let fallbackUserDisplayPrefix: String = "Użytkownik"
}
