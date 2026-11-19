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
    static let redesignKeys = [
      "common.close",
      "date.today",
      "date.yesterday",
      "verified.info.title",
      "verified.info.cloud.title",
      "verified.info.cloud.detail",
      "verified.info.server.title",
      "verified.info.server.detail",
      "verified.info.author.title",
      "verified.info.author.detail",
      "verified.info.original.title",
      "verified.info.original.detail",
      "verified.info.footer",
      "verified.info.entry.title",
      "verified.info.entry.cloud.title",
      "verified.info.entry.cloud.detail",
      "verified.info.entry.server.title",
      "verified.info.entry.server.detail",
      "verified.info.entry.author.title",
      "verified.info.entry.author.detail",
      "verified.info.entry.edit.title",
      "verified.info.entry.edit.detail",
      "verified.info.entry.footer",
      "local.info.title",
      "local.info.device.title",
      "local.info.device.detail",
      "local.info.unverified.title",
      "local.info.unverified.detail",
      "local.info.footer",
      "media.marker.instruction",
      "media.summary.save.sheet.title",
      "media.summary.save.a11y",
      "media.summary.action.local",
      "media.summary.action.local.subtitle",
      "media.summary.action.cloud",
      "media.summary.action.cloud.subtitle",
      "media.summary.title.single",
      "media.summary.pager.format",
      "media.summary.pager.previous",
      "media.summary.pager.next",
      "media.summary.marker.delete",
      "media.markers.show",
      "media.markers.hide",
      "media.detail.entries.header",
      "media.detail.entry.retract.confirm.message",
      "media.detail.metadata.captured.label",
      "media.detail.metadata.cloud.label",
      "media.detail.metadata.source.label",
      "media.detail.metadata.status.label",
    ]
  }

  @Test("Resolves Polish localized strings from Bundle.module")
  func resolvesPolishStrings() {
    let headline = L10n.string("onboarding.headline")
    #expect(!headline.isEmpty && headline != "onboarding.headline")
    #expect(L10n.string("apartments.list.title") == "Mieszkania")

    for key in Fixtures.redesignKeys {
      let value = L10n.string(key)
      #expect(!value.isEmpty && value != key)
    }
    #expect(L10n.string("media.summary.action.cloud") == "Chmura")
    #expect(L10n.string("media.detail.metadata.cloud.label") == "Zapisane")
    #expect(L10n.summaryMultiTitle(Fixtures.twoCount) == "2 zdjęcia")
    #expect(L10n.summaryMultiTitle(Fixtures.fiveCount) == "5 zdjęć")
  }

  @Test("Resolves sharing, profile, and join sheet Polish keys")
  func resolvesWS6PolishStrings() {
    let ws6Keys = [
      "sharing.share.cta",
      "sharing.code.tapToCopy",
      "sharing.code.copied.short",
      "profile.name.label",
      "profile.name.save",
      "profile.name.footer",
      "profile.theme.section",
      "profile.theme.picker",
      "profile.delete.footer",
      "apartments.join.code.prompt",
      "apartments.join.code.footer",
    ]
    for key in ws6Keys {
      let value = L10n.string(key)
      #expect(!value.isEmpty)
      #expect(value != key)
    }
    #expect(L10n.string("apartments.join.code.prompt") == "K7QM-4XPB")
    #expect(L10n.string("sharing.share.cta") == "Udostępnij")
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

  @Test("Maps NETWORK_UNAVAILABLE code and connectivity URLErrors to network unavailable message")
  func mapsNetworkUnavailableErrors() {
    let expected = L10n.string("error.NETWORK_UNAVAILABLE")
    let unknown = L10n.string("error.UNKNOWN")
    #expect(expected != unknown)
    #expect(L10n.errorMessage(for: .unknown(L10n.networkUnavailableErrorCode)) == expected)
    #expect(L10n.errorMessage(for: URLError(.cannotConnectToHost)) == expected)
    #expect(L10n.errorMessage(for: URLError(.notConnectedToInternet)) == expected)
    #expect(L10n.errorMessage(for: URLError(.timedOut)) == expected)

    let wrapped = NSError(
      domain: "TestWrapper",
      code: 1,
      userInfo: [NSUnderlyingErrorKey: URLError(.cannotConnectToHost)]
    )
    #expect(L10n.errorMessage(for: wrapped) == expected)
    #expect(L10n.errorMessage(for: NSError(domain: "OtherDomain", code: 1)) == unknown)
  }
}
