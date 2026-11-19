import Foundation
import Testing

@testable import Domain

@Suite("PolishDateFormatters Tests")
struct PolishDateFormattersTests {
  private enum Fixtures {
    static let year = 2_026
    static let previousYear = 2_025
    static let october = 10
    static let november = 11
    static let dayNineteen = 19
    static let dayEighteen = 18
    static let dayTwentyThree = 23
    static let dayTwentyFive = 25
    static let hourFourteen = 14
    static let hourTwelve = 12
    static let hourTwo = 2
    static let hourZero = 0
    static let minuteFive = 5
    static let minuteNine = 9
    static let minuteThirty = 30
    static let secondFortyOne = 41
    static let futureMinutesOffset: TimeInterval = 600
    static let warsawTimeZoneId = "Europe/Warsaw"
    static let utcTimeZoneId = "UTC"
  }

  @Test("Formats today, yesterday, and same-year human Polish timestamps")
  func formatsTodayYesterdayAndSameYear() throws {
    let warsaw = try #require(TimeZone(identifier: Fixtures.warsawTimeZoneId))
    let now = try makeDate(
      DateComponents(
        year: Fixtures.year, month: Fixtures.november, day: Fixtures.dayNineteen,
        hour: Fixtures.hourFourteen, minute: Fixtures.minuteThirty
      ),
      timeZone: warsaw
    )
    let today = try makeDate(
      DateComponents(
        year: Fixtures.year, month: Fixtures.november, day: Fixtures.dayNineteen,
        hour: Fixtures.hourFourteen, minute: Fixtures.minuteFive
      ),
      timeZone: warsaw
    )
    let yesterday = try makeDate(
      DateComponents(
        year: Fixtures.year, month: Fixtures.november, day: Fixtures.dayEighteen,
        hour: Fixtures.hourTwelve, minute: Fixtures.minuteNine
      ),
      timeZone: warsaw
    )
    let sameYear = try makeDate(
      DateComponents(
        year: Fixtures.year, month: Fixtures.october, day: Fixtures.dayTwentyThree,
        hour: Fixtures.hourTwelve, minute: Fixtures.minuteNine
      ),
      timeZone: warsaw
    )

    #expect(
      PolishDateFormatters.formatHumanTimestamp(today, now: now, timeZone: warsaw)
        == "Dzisiaj, 14:05"
    )
    #expect(
      PolishDateFormatters.formatHumanTimestamp(yesterday, now: now, timeZone: warsaw)
        == "Wczoraj, 12:09"
    )
    #expect(
      PolishDateFormatters.formatHumanTimestamp(sameYear, now: now, timeZone: warsaw)
        == "23 października, 12:09"
    )
  }

  @Test("Formats previous year, future clock skew, and precise evidence timestamps")
  func formatsPreviousYearFutureAndPrecise() throws {
    let warsaw = try #require(TimeZone(identifier: Fixtures.warsawTimeZoneId))
    let now = try makeDate(
      DateComponents(
        year: Fixtures.year, month: Fixtures.november, day: Fixtures.dayNineteen,
        hour: Fixtures.hourFourteen, minute: Fixtures.minuteThirty
      ),
      timeZone: warsaw
    )
    let previousYear = try makeDate(
      DateComponents(
        year: Fixtures.previousYear, month: Fixtures.october, day: Fixtures.dayTwentyThree,
        hour: Fixtures.hourTwelve, minute: Fixtures.minuteNine
      ),
      timeZone: warsaw
    )
    let preciseSample = try makeDate(
      DateComponents(
        year: Fixtures.year, month: Fixtures.october, day: Fixtures.dayTwentyThree,
        hour: Fixtures.hourTwelve, minute: Fixtures.minuteNine, second: Fixtures.secondFortyOne
      ),
      timeZone: warsaw
    )
    let futureSkew = now.addingTimeInterval(Fixtures.futureMinutesOffset)

    #expect(
      PolishDateFormatters.formatHumanTimestamp(previousYear, now: now, timeZone: warsaw)
        == "23 października 2025, 12:09"
    )
    #expect(
      PolishDateFormatters.formatHumanTimestamp(futureSkew, now: now, timeZone: warsaw)
        == "19 listopada, 14:40"
    )
    #expect(
      PolishDateFormatters.formatPreciseTimestamp(preciseSample, timeZone: warsaw)
        == "23 października 2026, 12:09:41"
    )
  }

  @Test("Capitalizes Polish weekdays in timeline day headers")
  func formatsDayHeaders() throws {
    let warsaw = try #require(TimeZone(identifier: Fixtures.warsawTimeZoneId))
    let now = try makeDate(
      DateComponents(
        year: Fixtures.year, month: Fixtures.november, day: Fixtures.dayNineteen,
        hour: Fixtures.hourFourteen, minute: Fixtures.minuteFive
      ),
      timeZone: warsaw
    )
    let octoberFriday = try makeDate(
      DateComponents(
        year: Fixtures.year, month: Fixtures.october, day: Fixtures.dayTwentyThree,
        hour: Fixtures.hourTwelve, minute: Fixtures.minuteFive
      ),
      timeZone: warsaw
    )
    let previousYearDate = try makeDate(
      DateComponents(
        year: Fixtures.previousYear, month: Fixtures.october, day: Fixtures.dayTwentyThree,
        hour: Fixtures.hourTwelve, minute: Fixtures.minuteFive
      ),
      timeZone: warsaw
    )

    #expect(
      PolishDateFormatters.formatTimelineDayHeader(octoberFriday, now: now, timeZone: warsaw)
        == "23 października, Piątek"
    )
    #expect(
      PolishDateFormatters.formatTimelineDayHeader(previousYearDate, now: now, timeZone: warsaw)
        == "23 października 2025, Czwartek"
    )
  }

  @Test("Respects Europe/Warsaw DST fallback boundary and day grouping key")
  func respectsWarsawDSTBoundary() throws {
    let warsaw = try #require(TimeZone(identifier: Fixtures.warsawTimeZoneId))
    let utc = try #require(TimeZone(identifier: Fixtures.utcTimeZoneId))
    let beforeDstFallback = try makeDate(
      DateComponents(
        year: Fixtures.year, month: Fixtures.october, day: Fixtures.dayTwentyFive,
        hour: Fixtures.hourZero, minute: Fixtures.minuteThirty
      ),
      timeZone: utc
    )
    let afterDstFallback = try makeDate(
      DateComponents(
        year: Fixtures.year, month: Fixtures.october, day: Fixtures.dayTwentyFive,
        hour: Fixtures.hourTwo, minute: Fixtures.minuteThirty
      ),
      timeZone: utc
    )

    #expect(
      PolishDateFormatters.formatPreciseTimestamp(beforeDstFallback, timeZone: warsaw)
        == "25 października 2026, 02:30:00"
    )
    #expect(
      PolishDateFormatters.formatPreciseTimestamp(afterDstFallback, timeZone: warsaw)
        == "25 października 2026, 03:30:00"
    )

    var warsawCalendar = Calendar(identifier: .gregorian)
    warsawCalendar.timeZone = warsaw
    #expect(
      PolishDateFormatters.dayGroupingKey(beforeDstFallback, calendar: warsawCalendar)
        == "2026-10-25"
    )
  }

  private func makeDate(_ components: DateComponents, timeZone: TimeZone) throws -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    var datedComponents = components
    datedComponents.timeZone = timeZone
    return try #require(calendar.date(from: datedComponents))
  }
}
