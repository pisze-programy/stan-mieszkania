import Testing

@testable import Domain

@Suite("AuthorBadgePolicy Tests")
struct AuthorBadgePolicyTests {
  @Test("Extracts deterministic initials for standard, fallback, anonymized, and single names")
  func extractsInitials() {
    #expect(AuthorBadgePolicy.initials(for: "Jan Kowalski") == "JK")
    #expect(AuthorBadgePolicy.initials(for: "Użytkownik #DCSG") == "DC")
    #expect(AuthorBadgePolicy.initials(for: "Użytkownik #A1B2") == "A1")
    #expect(AuthorBadgePolicy.initials(for: "Usunięty użytkownik") == "UU")
    #expect(AuthorBadgePolicy.initials(for: "Anna") == "AN")
    #expect(AuthorBadgePolicy.initials(for: "   ") == "?")

    let fallbackUser = UserProfile(
      id: "u1",
      displayName: "Użytkownik #DCSG",
      shortTag: "DCSG",
      color: DomainConstants.defaultAuthorColor,
      createdAt: .distantPast
    )
    let customUser = UserProfile(
      id: "u2",
      displayName: "Jan Kowalski",
      shortTag: "DCSG",
      color: DomainConstants.defaultAuthorColor,
      createdAt: .distantPast
    )
    #expect(!fallbackUser.hasCustomDisplayName)
    #expect(customUser.hasCustomDisplayName)
  }

  @Test("Validates hex color with ContractConstants palette fallback and deterministic seeding")
  func resolvesPaletteColors() {
    let validHex = "#34C759"
    let defaultHex =
      ContractConstants.authorColorPalette.first ?? DomainConstants.defaultAuthorColor

    #expect(AuthorBadgePolicy.resolvedHexColor(validHex) == validHex)
    #expect(AuthorBadgePolicy.resolvedHexColor("invalid") == defaultHex)
    #expect(AuthorBadgePolicy.resolvedHexColor(nil) == defaultHex)

    let firstColor = AuthorBadgePolicy.deterministicPaletteColor(for: "firebase-uid-1")
    let secondColor = AuthorBadgePolicy.deterministicPaletteColor(for: "firebase-uid-1")
    #expect(firstColor == secondColor)
    #expect(ContractConstants.authorColorPalette.contains(firstColor))
  }
}
