import Domain
import SwiftUI

public enum HighlightedEntryTextBuilder: Sendable {
  private static let tokenTintOpacity: Double = 0.22
  private static let clauseTintOpacity: Double = 0.1

  public static func buildAttributedString(
    text: String,
    selectedMarkerNumber: Int?,
    highlightColor: Color
  ) -> AttributedString {
    let segments = MarkerTextPolicy.parseSegments(in: text)
    let highlightedTextIndices = highlightedClauseIndices(
      in: segments,
      selectedMarkerNumber: selectedMarkerNumber
    )

    var result = AttributedString()
    for (index, segment) in segments.enumerated() {
      switch segment {
      case .text(let chunk):
        var part = AttributedString(chunk)
        if highlightedTextIndices.contains(index) {
          part.foregroundColor = highlightColor
          part.backgroundColor = highlightColor.opacity(clauseTintOpacity)
        }
        result.append(part)
      case .marker(let number, let rawToken):
        var part = AttributedString(rawToken)
        if selectedMarkerNumber == number {
          part.foregroundColor = highlightColor
          part.backgroundColor = highlightColor.opacity(tokenTintOpacity)
          part.inlinePresentationIntent = .stronglyEmphasized
        } else {
          part.foregroundColor = highlightColor
          part.inlinePresentationIntent = .stronglyEmphasized
        }
        result.append(part)
      }
    }
    return result
  }

  // Decision Q14: Highlight the selected [n] token and its associated text clause.
  private static func highlightedClauseIndices(
    in segments: [MarkerTextSegment],
    selectedMarkerNumber: Int?
  ) -> Set<Int> {
    guard let selectedMarkerNumber else {
      return []
    }

    var indices: Set<Int> = []
    for (index, segment) in segments.enumerated() {
      guard case .marker(let number, _) = segment, number == selectedMarkerNumber else {
        continue
      }

      let nextIndex = index + 1
      if isNonEmptyTextSegment(at: nextIndex, in: segments) {
        indices.insert(nextIndex)
        continue
      }

      let previousIndex = index - 1
      if isNonEmptyTextSegment(at: previousIndex, in: segments) {
        indices.insert(previousIndex)
      }
    }
    return indices
  }

  private static func isNonEmptyTextSegment(
    at index: Int,
    in segments: [MarkerTextSegment]
  ) -> Bool {
    guard index >= 0, index < segments.count, case .text(let chunk) = segments[index] else {
      return false
    }
    return !chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

public struct HighlightedEntryTextView: View {
  private let text: String
  private let selectedMarkerNumber: Int?
  private let authorColorHex: String

  public init(
    text: String,
    selectedMarkerNumber: Int?,
    authorColorHex: String
  ) {
    self.text = text
    self.selectedMarkerNumber = selectedMarkerNumber
    self.authorColorHex = authorColorHex
  }

  public var body: some View {
    Text(
      HighlightedEntryTextBuilder.buildAttributedString(
        text: text,
        selectedMarkerNumber: selectedMarkerNumber,
        highlightColor: AuthorPalette.color(fromHex: authorColorHex)
      )
    )
    .font(Typography.body)
  }
}
