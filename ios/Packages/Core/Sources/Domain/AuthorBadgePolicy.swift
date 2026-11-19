import Foundation

public enum AuthorBadgePolicy: Sendable {
  private static let fallbackPrefixWithHash: String =
    "\(DomainConstants.fallbackUserDisplayPrefix) #"
  private static let hashPrefix: String = "#"
  private static let emptyPlaceholder: String = "?"
  private static let singleWordInitialsMaxLength: Int = 2
  private static let twoWordsMinimumCount: Int = 2
  private static let colorSeedPrefix: String = "color:"
  private static let hexColorPattern: String = #"^#[0-9A-Fa-f]{6}$"#
  private static let fnv1aOffsetBasis: UInt32 = 2_166_136_261
  private static let fnv1aPrime: UInt32 = 16_777_619

  public static func initials(for displayName: String) -> String {
    let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return emptyPlaceholder
    }

    // Decision S2-14: Fallback display names 'Użytkownik #A1B2' render '#A' as badge initials.
    if trimmed.hasPrefix(fallbackPrefixWithHash) {
      let tagSuffix = trimmed.dropFirst(fallbackPrefixWithHash.count)
      if let firstTagCharacter = tagSuffix.first {
        return "\(hashPrefix)\(String(firstTagCharacter).uppercased())"
      }
    }

    let words = trimmed.split(whereSeparator: \.isWhitespace)
    guard words.count >= twoWordsMinimumCount else {
      return String(trimmed.prefix(singleWordInitialsMaxLength)).uppercased()
    }

    guard let firstInitial = words.first?.first, let lastInitial = words.last?.first else {
      return emptyPlaceholder
    }
    return "\(firstInitial)\(lastInitial)".uppercased()
  }

  public static func resolvedHexColor(_ hex: String?) -> String {
    guard
      let hex,
      hex.range(of: hexColorPattern, options: .regularExpression) != nil
    else {
      return ContractConstants.authorColorPalette.first ?? DomainConstants.defaultAuthorColor
    }
    return hex
  }

  public static func deterministicPaletteColor(for seed: String) -> String {
    let palette = ContractConstants.authorColorPalette
    guard !palette.isEmpty else {
      return DomainConstants.defaultAuthorColor
    }

    let hash = fnv1aHash("\(colorSeedPrefix)\(seed)")
    let index = Int(hash) % palette.count
    return palette[index]
  }

  private static func fnv1aHash(_ input: String) -> UInt32 {
    var hash = fnv1aOffsetBasis
    for codeUnit in input.utf16 {
      hash ^= UInt32(codeUnit)
      hash = hash &* fnv1aPrime
    }
    return hash
  }
}
