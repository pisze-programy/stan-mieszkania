import Domain
import Foundation
import Testing

@testable import DesignSystem

@Suite("L10n Tests")
struct L10nTests {
  private enum Fixtures {
    static let zeroCount = 0
    static let oneCount = 1
    static let twoCount = 2
    static let fiveCount = 5
    static let twentyTwoCount = 22
    static let twentyFiveCount = 25
    static let expectedErrorCount = 53
  }

  @Test("Resolves Polish localized strings from Bundle.module")
  func resolvesPolishStrings() {
    let headline = L10n.string("onboarding.headline")
    #expect(!headline.isEmpty)
    #expect(headline != "onboarding.headline")

    let apartmentsTitle = L10n.string("apartments.list.title")
    #expect(apartmentsTitle == "Mieszkania")
  }

  @Test("Formats Polish plural photo counts for one, few, and many")
  func formatsPolishPlurals() {
    #expect(L10n.photoCount(Fixtures.oneCount) == "1 zdjęcie")
    #expect(L10n.photoCount(Fixtures.twoCount) == "2 zdjęcia")
    #expect(L10n.photoCount(Fixtures.fiveCount) == "5 zdjęć")
    #expect(L10n.photoCount(Fixtures.zeroCount) == "0 zdjęć")
    #expect(L10n.photoCount(Fixtures.twentyTwoCount) == "22 zdjęcia")
    #expect(L10n.photoCount(Fixtures.twentyFiveCount) == "25 zdjęć")
  }

  @Test("Maps all 53 DomainErrorCode cases and unknown fallback to non-empty Polish strings")
  func resolvesAllDomainErrorCodes() {
    #expect(DomainErrorCode.allCases.count == Fixtures.expectedErrorCount)

    for code in DomainErrorCode.allCases {
      let message = L10n.errorMessage(for: code)
      #expect(!message.isEmpty)
      #expect(message != "error.\(code.rawValue)")
    }

    let unknownMessage = L10n.errorMessage(for: .unknown("SOME_FUTURE_ERROR"))
    #expect(!unknownMessage.isEmpty)
    #expect(unknownMessage != "error.UNKNOWN")
  }
}
