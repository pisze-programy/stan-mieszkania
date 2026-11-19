import Foundation
import OpenAPIRuntime

struct FlexibleISO8601DateTranscoder: DateTranscoder, Sendable {
  func encode(_ date: Date) throws -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  func decode(_ dateString: String) throws -> Date {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let parsed = fractional.date(from: dateString) {
      return parsed
    }

    let wholeSeconds = ISO8601DateFormatter()
    wholeSeconds.formatOptions = [.withInternetDateTime]
    if let parsed = wholeSeconds.date(from: dateString) {
      return parsed
    }

    throw DecodingError.dataCorrupted(
      .init(codingPath: [], debugDescription: "Invalid ISO-8601 date: \(dateString)")
    )
  }
}
