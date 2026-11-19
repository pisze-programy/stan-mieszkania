import Dependencies
import Foundation
import Testing

@testable import Domain

@Suite("UUIDv7 Tests")
struct UUIDv7Tests {
  private enum Fixtures {
    static let sampleTimestampMs: Int64 = 0x0193_3E2A_7B40
    static let samplePrefixHex = "01933e2a-7b40-7"
    static let earlierTimestampMs: Int64 = 1_700_000_000_000
    static let laterTimestampMs: Int64 = 1_700_000_000_001
    static let overflowTimestampMs: Int64 = 0x1_0000_0000_0000
    static let negativeTimestampMs: Int64 = -1
    static let shortRandomByteCount = 15
    static let fillByte: UInt8 = 0xFF
    static let zeroByte: UInt8 = 0x00
    static let expectedMinUuid = "00000000-0000-7000-8000-000000000000"
    static let expectedMaxTimestampPrefix = "ffffffff-ffff-7fff-bfff-ffffffffffff"
    static let versionIndex = 14
    static let variantIndex = 19
    static let expectedVersionChar: Character = "7"
    static let validVariantChars: Set<Character> = ["8", "9", "a", "b"]
    static let invalidUuidV4 = "01933e2a-7b40-4000-8000-000000000001"
    static let invalidVariantUuid = "01933e2a-7b40-7000-c000-000000000001"
    static let validUppercaseUuid = "01933E2A-7B40-7000-8000-000000000001"
    static let stubbedId = "01933e2a-7b40-7000-8000-000000000001"
  }

  @Test("Sets RFC 9562 version 7 and variant 10xx bits in lowercase canonical string")
  func setsRfc9562BitsAndLowercaseFormat() throws {
    let randomBytes = [UInt8](repeating: Fixtures.fillByte, count: DomainConstants.UUIDv7.byteCount)
    let uuid = try UUIDv7.generate(
      timestampMs: Fixtures.sampleTimestampMs,
      randomBytes: randomBytes
    )

    #expect(uuid.hasPrefix(Fixtures.samplePrefixHex))
    #expect(uuid == uuid.lowercased())
    #expect(UUIDv7.isValid(uuid))

    let characters = Array(uuid)
    #expect(characters[Fixtures.versionIndex] == Fixtures.expectedVersionChar)
    #expect(Fixtures.validVariantChars.contains(characters[Fixtures.variantIndex]))
  }

  @Test("Produces lexicographically ordered UUIDs for increasing timestamps")
  func lexicographicOrderingAcrossTimestamps() throws {
    let fixedBytes = [UInt8](repeating: Fixtures.fillByte, count: DomainConstants.UUIDv7.byteCount)
    let first = try UUIDv7.generate(
      timestampMs: Fixtures.earlierTimestampMs,
      randomBytes: fixedBytes
    )
    let second = try UUIDv7.generate(
      timestampMs: Fixtures.laterTimestampMs,
      randomBytes: fixedBytes
    )

    #expect(first < second)
  }

  @Test("Enforces 48-bit timestamp bounds and random byte count")
  func enforcesBounds() throws {
    let zeroBytes = [UInt8](repeating: Fixtures.zeroByte, count: DomainConstants.UUIDv7.byteCount)
    let minUuid = try UUIDv7.generate(
      timestampMs: DomainConstants.UUIDv7.minTimestampMs,
      randomBytes: zeroBytes
    )
    #expect(minUuid == Fixtures.expectedMinUuid)

    let maxBytes = [UInt8](repeating: Fixtures.fillByte, count: DomainConstants.UUIDv7.byteCount)
    let maxUuid = try UUIDv7.generate(
      timestampMs: DomainConstants.UUIDv7.maxTimestampMs,
      randomBytes: maxBytes
    )
    #expect(maxUuid == Fixtures.expectedMaxTimestampPrefix)

    #expect(throws: UUIDv7Error.timestampOutOfRange(Fixtures.negativeTimestampMs)) {
      _ = try UUIDv7.generate(timestampMs: Fixtures.negativeTimestampMs)
    }

    #expect(throws: UUIDv7Error.timestampOutOfRange(Fixtures.overflowTimestampMs)) {
      _ = try UUIDv7.generate(timestampMs: Fixtures.overflowTimestampMs)
    }

    let shortBytes = [UInt8](repeating: Fixtures.zeroByte, count: Fixtures.shortRandomByteCount)
    #expect(throws: UUIDv7Error.invalidRandomBytesCount(Fixtures.shortRandomByteCount)) {
      _ = try UUIDv7.generate(timestampMs: Fixtures.sampleTimestampMs, randomBytes: shortBytes)
    }
  }

  @Test("Validates UUIDv7 strings and rejects non-v7 or malformed values")
  func validatesUuidV7Strings() {
    #expect(UUIDv7.isValid(Fixtures.validUppercaseUuid))
    #expect(!UUIDv7.isValid(Fixtures.invalidUuidV4))
    #expect(!UUIDv7.isValid(Fixtures.invalidVariantUuid))
    #expect(!UUIDv7.isValid("not-a-uuid"))
  }

  @Test("IDGenerator implementations return valid identifiers")
  func idGeneratorsWork() {
    let systemGenerator = SystemIDGenerator()
    let generated = systemGenerator.generate()
    #expect(UUIDv7.isValid(generated))

    let closureGenerator = ClosureIDGenerator { Fixtures.stubbedId }
    #expect(closureGenerator.generate() == Fixtures.stubbedId)
    #expect(UUIDv7.isValid(IDGeneratorKey.liveValue.generate()))
    #expect(UUIDv7.isValid(IDGeneratorKey.previewValue.generate()))

    withDependencies {
      $0.idGenerator = closureGenerator
    } operation: {
      @Dependency(\.idGenerator) var idGenerator
      #expect(idGenerator.generate() == Fixtures.stubbedId)
    }
  }
}
