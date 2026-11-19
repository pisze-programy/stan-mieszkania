import Domain
import SwiftUI

public enum HighlightedEntryTextBuilder: Sendable {
  private static let tokenTintOpacity: Double = 0.22
  private static let dimmedTokenOpacity: Double = 0.55

  public static func markerURL(for number: Int) -> URL? {
    URL(string: "marker://\(number)")
  }

  public static func markerNumber(from url: URL) -> Int? {
    guard url.scheme == "marker", let host = url.host() else {
      return nil
    }
    return Int(host)
  }

  public static func buildAttributedString(
    text: String,
    selectedMarkerNumber: Int?,
    linkedMarkerNumbers: Set<Int>
  ) -> AttributedString {
    let segments = MarkerTextPolicy.parseSegments(in: text)
    var result = AttributedString()
    for segment in segments {
      switch segment {
      case .text(let chunk):
        result.append(AttributedString(chunk))
      case .marker(let number, let rawToken):
        if linkedMarkerNumbers.contains(number) {
          result.append(
            markerTokenAttributedString(
              number: number,
              rawToken: rawToken,
              selectedMarkerNumber: selectedMarkerNumber
            )
          )
        } else {
          result.append(AttributedString(rawToken))
        }
      }
    }
    return result
  }

  static func markerTokenAttributedString(
    number: Int,
    rawToken: String,
    selectedMarkerNumber: Int?
  ) -> AttributedString {
    let baseColor = MarkerPalette.color(forMarkerNumber: number)
    let isSelected = selectedMarkerNumber == number
    let isDimmed = selectedMarkerNumber != nil && !isSelected
    var part = AttributedString(rawToken)
    part.foregroundColor = isDimmed ? baseColor.opacity(dimmedTokenOpacity) : baseColor
    part.font = .body.weight(.semibold).monospacedDigit()
    part.link = markerURL(for: number)
    if isSelected {
      part.backgroundColor = baseColor.opacity(tokenTintOpacity)
      part.inlinePresentationIntent = .stronglyEmphasized
    }
    return part
  }
}

public struct HighlightedEntryTextView: View {
  private let text: String
  private let selectedMarkerNumber: Int?
  private let linkedMarkerNumbers: Set<Int>
  private let onMarkerTapped: (Int) -> Void

  public init(
    text: String,
    selectedMarkerNumber: Int?,
    linkedMarkerNumbers: Set<Int>,
    onMarkerTapped: @escaping (Int) -> Void = { _ in }
  ) {
    self.text = text
    self.selectedMarkerNumber = selectedMarkerNumber
    self.linkedMarkerNumbers = linkedMarkerNumbers
    self.onMarkerTapped = onMarkerTapped
  }

  public var body: some View {
    Text(
      HighlightedEntryTextBuilder.buildAttributedString(
        text: text,
        selectedMarkerNumber: selectedMarkerNumber,
        linkedMarkerNumbers: linkedMarkerNumbers
      )
    )
    .font(Typography.body)
    .tint(.primary)
    .environment(
      \.openURL,
      OpenURLAction { url in
        guard let markerNumber = HighlightedEntryTextBuilder.markerNumber(from: url) else {
          return .systemAction
        }
        onMarkerTapped(markerNumber)
        return .handled
      }
    )
  }
}
