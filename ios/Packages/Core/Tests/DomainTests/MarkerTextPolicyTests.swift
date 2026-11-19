import Testing

@testable import Domain

@Suite("MarkerTextPolicy Tests")
struct MarkerTextPolicyTests {
  private enum Fixtures {
    static let markerOne = 1
    static let markerTwo = 2
    static let markerThree = 3
    static let markerFour = 4
    static let markerFive = 5
    static let markerTen = 10
    static let markerTwelve = 12
  }

  @Test("Collects unique referenced marker numbers while ignoring malformed or zero tokens")
  func collectsReferencedMarkerNumbers() {
    #expect(MarkerTextPolicy.referencedMarkerNumbers(in: "").isEmpty)
    #expect(MarkerTextPolicy.referencedMarkerNumbers(in: "Brak uwag").isEmpty)
    #expect(
      MarkerTextPolicy.referencedMarkerNumbers(in: "[1] rysa [1]") == [Fixtures.markerOne]
    )
    #expect(MarkerTextPolicy.referencedMarkerNumbers(in: "[1 rysa [0] [01]").isEmpty)
    #expect(
      MarkerTextPolicy.referencedMarkerNumbers(in: "Okno [12] i próg [2]")
        == [Fixtures.markerTwo, Fixtures.markerTwelve]
    )
  }

  @Test("Parses plain text, valid marker tokens, and ignores invalid bracket tokens")
  func parsesSegments() {
    #expect(MarkerTextPolicy.parseSegments(in: "").isEmpty)
    #expect(MarkerTextPolicy.parseSegments(in: "Brak uwag") == [.text("Brak uwag")])

    let mixed = MarkerTextPolicy.parseSegments(in: "[1] Rysa na drzwiach [2]")
    #expect(
      mixed == [
        .marker(number: Fixtures.markerOne, rawToken: "[1]"),
        .text(" Rysa na drzwiach "),
        .marker(number: Fixtures.markerTwo, rawToken: "[2]"),
      ]
    )

    let invalidTokens = MarkerTextPolicy.parseSegments(in: "Test [0] [01] [abc] [12")
    #expect(invalidTokens == [.text("Test [0] [01] [abc] [12")])
  }

  @Test("Appends marker token with trailing space and clean whitespace handling")
  func appendsMarkerToken() {
    #expect(MarkerTextPolicy.appendMarkerToken(to: "", number: Fixtures.markerOne) == "[1] ")
    #expect(MarkerTextPolicy.appendMarkerToken(to: "   ", number: Fixtures.markerOne) == "[1] ")
    #expect(
      MarkerTextPolicy.appendMarkerToken(to: "Rysa", number: Fixtures.markerOne) == "Rysa [1] "
    )
    #expect(
      MarkerTextPolicy.appendMarkerToken(to: "Rysa ", number: Fixtures.markerOne) == "Rysa [1] "
    )
    #expect(
      MarkerTextPolicy.appendMarkerToken(to: "[1] ", number: Fixtures.markerTwo) == "[1] [2] "
    )
    #expect(
      MarkerTextPolicy.appendMarkerToken(to: "Rysa\n", number: Fixtures.markerTwo) == "Rysa\n[2] "
    )
  }

  @Test("Removes target marker token cleanly without disturbing neighboring tokens")
  func removesMarkerToken() {
    #expect(MarkerTextPolicy.removeMarkerToken(from: "[1]", number: Fixtures.markerOne).isEmpty)
    #expect(
      MarkerTextPolicy.removeMarkerToken(from: "Rysa [1]", number: Fixtures.markerOne) == "Rysa"
    )
    #expect(
      MarkerTextPolicy.removeMarkerToken(from: "[1] Rysa", number: Fixtures.markerOne) == "Rysa"
    )
    #expect(
      MarkerTextPolicy.removeMarkerToken(from: "Rysa [1] na szybie", number: Fixtures.markerOne)
        == "Rysa na szybie"
    )
    #expect(
      MarkerTextPolicy.removeMarkerToken(from: "Rysa [1] [2]", number: Fixtures.markerOne)
        == "Rysa [2]"
    )
    #expect(
      MarkerTextPolicy.removeMarkerToken(from: "Rysa [1] ", number: Fixtures.markerOne) == "Rysa"
    )
    #expect(
      MarkerTextPolicy.removeMarkerToken(from: "Rysa [10]", number: Fixtures.markerOne)
        == "Rysa [10]"
    )
  }

  @Test("Rewrites marker tokens in a single pass without cascading overlaps")
  func rewritesMarkerTokensSinglePass() {
    let mapping: [Int: Int] = [
      Fixtures.markerTwo: Fixtures.markerThree,
      Fixtures.markerThree: Fixtures.markerFour,
    ]
    let rewritten = MarkerTextPolicy.rewriteMarkerTokens(
      in: "Szyba [2], klamka [3], próg [1]",
      mapping: mapping
    )
    #expect(rewritten == "Szyba [3], klamka [4], próg [1]")
  }

  @Test("Computes next draft marker number after existing and draft numbers")
  func computesNextDraftMarkerNumber() {
    #expect(
      MarkerTextPolicy.nextDraftMarkerNumber(existingMaxNumber: 0, currentDraftNumbers: [])
        == Fixtures.markerOne
    )
    #expect(
      MarkerTextPolicy.nextDraftMarkerNumber(
        existingMaxNumber: 0,
        currentDraftNumbers: [Fixtures.markerOne, Fixtures.markerTwo]
      ) == Fixtures.markerThree
    )
    #expect(
      MarkerTextPolicy.nextDraftMarkerNumber(
        existingMaxNumber: Fixtures.markerFive,
        currentDraftNumbers: [Fixtures.markerTwo]
      ) == Fixtures.markerFive + 1
    )
    #expect(
      MarkerTextPolicy.nextDraftMarkerNumber(
        existingMaxNumber: Fixtures.markerFive,
        currentDraftNumbers: [Fixtures.markerTen]
      ) == Fixtures.markerTen + 1
    )
  }
}
