import Foundation
import Testing

@testable import Domain

@Suite("PolishDateFormatters Tests")
struct PolishDateFormattersTests {
  private enum Fixtures {
    static let year = 2_026
    static let month = 11
    static let day = 19
    static let hour = 14
    static let minute = 5
    static let warsawTimeZoneId = "Europe/Warsaw"
    static let utcTimeZoneId = "UTC"
  }

  @Test("Formats timestamps, timeline day headers, and grouping keys deterministically in pl_PL")
  func formatsPolishDates() throws {
    let warsawTimeZone = try #require(TimeZone(identifier: Fixtures.warsawTimeZoneId))
    let utcTimeZone = try #require(TimeZone(identifier: Fixtures.utcTimeZoneId))

    var warsawCalendar = Calendar(identifier: .gregorian)
    warsawCalendar.timeZone = warsawTimeZone

    let components = DateComponents(
      timeZone: warsawTimeZone,
      year: Fixtures.year,
      month: Fixtures.month,
      day: Fixtures.day,
      hour: Fixtures.hour,
      minute: Fixtures.minute
    )
    let date = try #require(warsawCalendar.date(from: components))

    #expect(
      PolishDateFormatters.formatTimestamp(date, timeZone: warsawTimeZone) == "19/11/2026 14:05"
    )
    #expect(
      PolishDateFormatters.formatTimestamp(date, timeZone: utcTimeZone) == "19/11/2026 13:05"
    )
    #expect(
      PolishDateFormatters.formatTimelineDayHeader(date, timeZone: warsawTimeZone)
        == "19 listopada, czwartek"
    )
    #expect(PolishDateFormatters.dayGroupingKey(date, calendar: warsawCalendar) == "2026-11-19")
  }
}
