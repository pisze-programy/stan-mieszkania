import Testing

@testable import Domain

@Suite("InviteCodeFormatter Tests")
struct InviteCodeFormatterTests {
  @Test("Formats raw input into uppercase XXXX-XXXX and caps at 8 alphanumeric characters")
  func formatsInput() {
    #expect(InviteCodeFormatter.formatInput("ab") == "AB")
    #expect(InviteCodeFormatter.formatInput("k7qm") == "K7QM")
    #expect(InviteCodeFormatter.formatInput("k7qm4") == "K7QM-4")
    #expect(InviteCodeFormatter.formatInput("k7qm 4xpb") == "K7QM-4XPB")
    #expect(InviteCodeFormatter.formatInput("k7qm-4xpb-999") == "K7QM-4XPB")
  }

  @Test("Validates 8-character invite codes strictly against ContractConstants.inviteCodeAlphabet")
  func validatesAlphabetAndLength() {
    #expect(InviteCodeFormatter.validate("k7qm-4xpb") == "K7QM-4XPB")
    #expect(InviteCodeFormatter.validate("K7QM 4XPB") == "K7QM-4XPB")
    #expect(InviteCodeFormatter.validate("K7QM4XPB") == "K7QM-4XPB")

    #expect(InviteCodeFormatter.validate("K7QM-4XP") == nil)
    #expect(InviteCodeFormatter.validate("K7QM-4XPBB") == nil)
    #expect(InviteCodeFormatter.validate("K7QM-0XPB") == nil)
    #expect(InviteCodeFormatter.validate("K7QM-OXPB") == nil)
    #expect(InviteCodeFormatter.validate("K7QM-1XPB") == nil)
    #expect(InviteCodeFormatter.validate("K7QM-IXPB") == nil)
  }
}
