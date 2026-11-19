import Foundation

public enum MarkerTextSegment: Sendable, Equatable, Hashable {
  case text(String)
  case marker(number: Int, rawToken: String)
}

public enum MarkerTextPolicy: Sendable {
  private static let tokenPattern: String = #"\[([1-9][0-9]*)\]"#
  private static let space: String = " "
  private static let openBracket: String = "["
  private static let closeBracket: String = "]"
  private static let horizontalWhitespace: Set<Character> = [" ", "\t"]

  public static func parseSegments(in text: String) -> [MarkerTextSegment] {
    guard !text.isEmpty else {
      return []
    }

    guard let regex = try? NSRegularExpression(pattern: tokenPattern) else {
      return [.text(text)]
    }

    let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
    let matches = regex.matches(in: text, range: fullRange)
    guard !matches.isEmpty else {
      return [.text(text)]
    }

    var segments: [MarkerTextSegment] = []
    var cursor = text.startIndex

    for match in matches {
      guard
        let matchRange = Range(match.range, in: text),
        let digitsRange = Range(match.range(at: 1), in: text),
        let number = Int(text[digitsRange])
      else {
        continue
      }

      if cursor < matchRange.lowerBound {
        segments.append(.text(String(text[cursor..<matchRange.lowerBound])))
      }

      let rawToken = String(text[matchRange])
      segments.append(.marker(number: number, rawToken: rawToken))
      cursor = matchRange.upperBound
    }

    if cursor < text.endIndex {
      segments.append(.text(String(text[cursor..<text.endIndex])))
    }

    return segments
  }

  public static func referencedMarkerNumbers(in text: String) -> Set<Int> {
    var numbers: Set<Int> = []
    for segment in parseSegments(in: text) {
      if case .marker(let number, _) = segment {
        numbers.insert(number)
      }
    }
    return numbers
  }

  public static func appendMarkerToken(to text: String, number: Int) -> String {
    let token = formatToken(number)
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return "\(token)\(space)"
    }

    if text.last?.isWhitespace == true {
      return "\(text)\(token)\(space)"
    }
    return "\(text)\(space)\(token)\(space)"
  }

  public static func removeMarkerToken(from text: String, number: Int) -> String {
    let segments = parseSegments(in: text)
    var result = ""
    var stripLeadingSpaceOnNextText = false
    var pendingRemovalTrimAtEnd = false

    for segment in segments {
      switch segment {
      case .marker(let tokenNumber, let rawToken):
        if tokenNumber == number {
          let atLineStart = result.isEmpty || result.last?.isNewline == true
          let hasTrailingSpace = result.last.map { horizontalWhitespace.contains($0) } ?? false
          stripLeadingSpaceOnNextText = atLineStart || hasTrailingSpace
          pendingRemovalTrimAtEnd = true
        } else {
          result.append(rawToken)
          stripLeadingSpaceOnNextText = false
          pendingRemovalTrimAtEnd = false
        }
      case .text(var chunk):
        if stripLeadingSpaceOnNextText {
          while let first = chunk.first, horizontalWhitespace.contains(first) {
            chunk.removeFirst()
          }
          stripLeadingSpaceOnNextText = false
        }
        if chunk.isEmpty {
          continue
        }
        if pendingRemovalTrimAtEnd, chunk.first?.isNewline == true {
          result = trimTrailingHorizontalWhitespace(result)
        }
        pendingRemovalTrimAtEnd = false
        result.append(chunk)
      }
    }

    if pendingRemovalTrimAtEnd {
      result = trimTrailingHorizontalWhitespace(result)
    }

    return result
  }

  // Decision S2-2: Rewrite [n] tokens in a single left-to-right pass so overlapping mappings never cascade.
  public static func rewriteMarkerTokens(in text: String, mapping: [Int: Int]) -> String {
    guard !mapping.isEmpty, !text.isEmpty else {
      return text
    }

    return parseSegments(in: text).map { segment in
      switch segment {
      case .text(let chunk):
        return chunk
      case .marker(let number, let rawToken):
        if let mapped = mapping[number] {
          return formatToken(mapped)
        }
        return rawToken
      }
    }.joined()
  }

  public static func nextDraftMarkerNumber(
    existingMaxNumber: Int,
    currentDraftNumbers: [Int]
  ) -> Int {
    let clampedExisting = max(0, existingMaxNumber)
    let maxDraft = currentDraftNumbers.max() ?? 0
    return max(clampedExisting, maxDraft) + 1
  }

  private static func formatToken(_ number: Int) -> String {
    "\(openBracket)\(number)\(closeBracket)"
  }

  private static func trimTrailingHorizontalWhitespace(_ value: String) -> String {
    var trimmed = value
    while let last = trimmed.last, horizontalWhitespace.contains(last) {
      trimmed.removeLast()
    }
    return trimmed
  }
}
