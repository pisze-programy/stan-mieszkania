import Foundation

public enum PolishDateFormatters: Sendable {
  private static let polishLocaleIdentifier: String = "pl_PL"
  private static let timestampFormat: String = "dd/MM/yyyy HH:mm"
  private static let timelineDayHeaderFormat: String = "d MMMM, EEEE"
  private static let dayGroupingFormat: String = "%04d-%02d-%02d"

  public static func formatTimestamp(_ date: Date, timeZone: TimeZone = .current) -> String {
    let formatter = makeFormatter(dateFormat: timestampFormat, timeZone: timeZone)
    return formatter.string(from: date)
  }

  // Decision S2-13 & S2-15: Timeline day headers render Polish locale date + weekday.
  public static func formatTimelineDayHeader(
    _ date: Date,
    timeZone: TimeZone = .current
  ) -> String {
    let formatter = makeFormatter(dateFormat: timelineDayHeaderFormat, timeZone: timeZone)
    return formatter.string(from: date)
  }

  public static func dayGroupingKey(_ date: Date, calendar: Calendar = .current) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    let year = components.year ?? 0
    let month = components.month ?? 0
    let day = components.day ?? 0
    return String(format: dayGroupingFormat, year, month, day)
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
