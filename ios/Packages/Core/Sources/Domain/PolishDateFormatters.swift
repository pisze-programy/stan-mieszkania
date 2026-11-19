import Foundation

public enum PolishDateFormatters: Sendable {
  private static let polishLocaleIdentifier: String = "pl_PL"
  private static let todayLabel: String = "Dzisiaj"
  private static let yesterdayLabel: String = "Wczoraj"
  private static let timeOnlyFormat: String = "HH:mm"
  private static let sameYearDateTimeFormat: String = "d MMMM, HH:mm"
  private static let fullDateTimeFormat: String = "d MMMM yyyy, HH:mm"
  private static let sameYearDayMonthFormat: String = "d MMMM"
  private static let fullDayMonthYearFormat: String = "d MMMM yyyy"
  private static let weekdayFormat: String = "EEEE"
  private static let preciseTimestampFormat: String = "d MMMM yyyy, HH:mm:ss"
  private static let dayGroupingFormat: String = "%04d-%02d-%02d"
  private static let yesterdayDayOffset: Int = -1

  public static func formatHumanTimestamp(
    _ date: Date,
    now: Date,
    timeZone: TimeZone = .current
  ) -> String {
    let calendar = makeGregorianCalendar(timeZone: timeZone)
    let isSameYear =
      calendar.component(.year, from: date) == calendar.component(.year, from: now)

    if date > now {
      let pattern = isSameYear ? sameYearDateTimeFormat : fullDateTimeFormat
      return makeFormatter(dateFormat: pattern, timeZone: timeZone).string(from: date)
    }

    if calendar.isDate(date, inSameDayAs: now) {
      let timeText = makeFormatter(dateFormat: timeOnlyFormat, timeZone: timeZone).string(
        from: date
      )
      return "\(todayLabel), \(timeText)"
    }

    let yesterday = calendar.date(byAdding: .day, value: yesterdayDayOffset, to: now)
    if let yesterday, calendar.isDate(date, inSameDayAs: yesterday) {
      let timeText = makeFormatter(dateFormat: timeOnlyFormat, timeZone: timeZone).string(
        from: date
      )
      return "\(yesterdayLabel), \(timeText)"
    }

    let pattern = isSameYear ? sameYearDateTimeFormat : fullDateTimeFormat
    return makeFormatter(dateFormat: pattern, timeZone: timeZone).string(from: date)
  }

  // Decision S2-13 & S2-15: Timeline day headers render Polish locale date + capitalized weekday.
  public static func formatTimelineDayHeader(
    _ date: Date,
    now: Date,
    timeZone: TimeZone = .current
  ) -> String {
    let calendar = makeGregorianCalendar(timeZone: timeZone)
    let isSameYear =
      calendar.component(.year, from: date) == calendar.component(.year, from: now)
    let datePattern = isSameYear ? sameYearDayMonthFormat : fullDayMonthYearFormat
    let datePart = makeFormatter(dateFormat: datePattern, timeZone: timeZone).string(from: date)
    let locale = Locale(identifier: polishLocaleIdentifier)
    let weekdayPart = makeFormatter(dateFormat: weekdayFormat, timeZone: timeZone)
      .string(from: date)
      .capitalized(with: locale)
    return "\(datePart), \(weekdayPart)"
  }

  public static func formatPreciseTimestamp(
    _ date: Date,
    timeZone: TimeZone = .current
  ) -> String {
    makeFormatter(dateFormat: preciseTimestampFormat, timeZone: timeZone).string(from: date)
  }

  public static func dayGroupingKey(_ date: Date, calendar: Calendar = .current) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    let year = components.year ?? 0
    let month = components.month ?? 0
    let day = components.day ?? 0
    return String(format: dayGroupingFormat, year, month, day)
  }

  private static func makeGregorianCalendar(timeZone: TimeZone) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar
  }

  private static func makeFormatter(dateFormat: String, timeZone: TimeZone) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: polishLocaleIdentifier)
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = timeZone
    formatter.dateFormat = dateFormat
    return formatter
  }
}
