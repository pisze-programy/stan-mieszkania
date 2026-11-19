import Foundation

public enum AppVersionPolicy: Sendable {
  private static let plusSeparator: Character = "+"
  private static let hyphenSeparator: Character = "-"
  private static let dotSeparator: Character = "."
  private static let coreComponentCount: Int = 3
  private static let minorIndex: Int = 1
  private static let patchIndex: Int = 2

  public static func isUpdateRequired(
    currentVersion: String,
    minSupportedVersion: String
  ) -> Bool {
    guard
      let current = SemVer.parse(currentVersion),
      let minSupported = SemVer.parse(minSupportedVersion)
    else {
      return false
    }
    return current < minSupported
  }

  private enum PreReleaseIdentifier: Comparable {
    case numeric(Int)
    case alphanumeric(String)

    static func parse(_ raw: String) -> PreReleaseIdentifier? {
      guard !raw.isEmpty else {
        return nil
      }
      if raw.allSatisfy(\.isASCII), raw.allSatisfy(\.isNumber), let value = Int(raw) {
        if raw.count > 1, raw.hasPrefix("0") {
          return nil
        }
        return .numeric(value)
      }
      return .alphanumeric(raw)
    }

    static func < (lhs: PreReleaseIdentifier, rhs: PreReleaseIdentifier) -> Bool {
      switch (lhs, rhs) {
      case (.numeric(let leftValue), .numeric(let rightValue)):
        return leftValue < rightValue
      case (.numeric, .alphanumeric):
        return true
      case (.alphanumeric, .numeric):
        return false
      case (.alphanumeric(let leftText), .alphanumeric(let rightText)):
        return leftText < rightText
      }
    }
  }

  private struct SemVer: Comparable {
    let major: Int
    let minor: Int
    let patch: Int
    let preRelease: [PreReleaseIdentifier]

    static func parse(_ raw: String) -> SemVer? {
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      let withoutBuild =
        trimmed.split(
          separator: plusSeparator,
          maxSplits: 1,
          omittingEmptySubsequences: false
        ).first.map(String.init) ?? trimmed

      let parts = withoutBuild.split(
        separator: hyphenSeparator,
        maxSplits: 1,
        omittingEmptySubsequences: false
      )
      guard let corePart = parts.first else {
        return nil
      }

      let coreStrings = corePart.split(
        separator: dotSeparator,
        omittingEmptySubsequences: false
      )
      guard coreStrings.count == coreComponentCount else {
        return nil
      }

      guard
        let major = parseNonNegativeCoreNumber(String(coreStrings[0])),
        let minor = parseNonNegativeCoreNumber(String(coreStrings[minorIndex])),
        let patch = parseNonNegativeCoreNumber(String(coreStrings[patchIndex]))
      else {
        return nil
      }

      var preRelease: [PreReleaseIdentifier] = []
      if parts.count > 1 {
        let rawIdentifiers = parts[1].split(
          separator: dotSeparator, omittingEmptySubsequences: false)
        guard !rawIdentifiers.isEmpty else {
          return nil
        }
        for identifier in rawIdentifiers {
          guard let parsed = PreReleaseIdentifier.parse(String(identifier)) else {
            return nil
          }
          preRelease.append(parsed)
        }
      }

      return SemVer(major: major, minor: minor, patch: patch, preRelease: preRelease)
    }

    static func < (lhs: SemVer, rhs: SemVer) -> Bool {
      if lhs.major != rhs.major {
        return lhs.major < rhs.major
      }
      if lhs.minor != rhs.minor {
        return lhs.minor < rhs.minor
      }
      if lhs.patch != rhs.patch {
        return lhs.patch < rhs.patch
      }

      if lhs.preRelease.isEmpty && rhs.preRelease.isEmpty {
        return false
      }
      if lhs.preRelease.isEmpty {
        return false
      }
      if rhs.preRelease.isEmpty {
        return true
      }

      for (leftId, rightId) in zip(lhs.preRelease, rhs.preRelease) where leftId != rightId {
        return leftId < rightId
      }
      return lhs.preRelease.count < rhs.preRelease.count
    }

    private static func parseNonNegativeCoreNumber(_ raw: String) -> Int? {
      guard !raw.isEmpty, raw.allSatisfy(\.isASCII), raw.allSatisfy(\.isNumber) else {
        return nil
      }
      if raw.count > 1, raw.hasPrefix("0") {
        return nil
      }
      return Int(raw)
    }
  }
}
