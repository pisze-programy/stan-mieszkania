import Foundation
import Testing

@testable import Domain

@Suite("DomainErrorCode Tests")
struct DomainErrorCodeTests {
  private enum Fixtures {
    static let unknownCode = "FUTURE_SERVER_ERROR"
    static let quotaRaw = "QUOTA_EXCEEDED"
  }

  @Test("Round-trips all DomainErrorCode cases through Codable")
  func domainErrorCodeCodableRoundTrip() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    for code in DomainErrorCode.allCases {
      let data = try encoder.encode(code)
      let decoded = try decoder.decode(DomainErrorCode.self, from: data)
      #expect(decoded == code)
    }
  }

  @Test("Encodes and decodes known and unknown ServerErrorCode values")
  func serverErrorCodeCodableBehavior() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let known = ServerErrorCode.known(.quotaExceeded)
    let knownData = try encoder.encode(known)
    let knownJson = String(bytes: knownData, encoding: .utf8)
    #expect(knownJson == "\"\(Fixtures.quotaRaw)\"")
    #expect(try decoder.decode(ServerErrorCode.self, from: knownData) == known)

    let unknown = ServerErrorCode.unknown(Fixtures.unknownCode)
    let unknownData = try encoder.encode(unknown)
    let unknownJson = String(bytes: unknownData, encoding: .utf8)
    #expect(unknownJson == "\"\(Fixtures.unknownCode)\"")
    #expect(try decoder.decode(ServerErrorCode.self, from: unknownData) == unknown)
  }
}
