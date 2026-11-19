import Foundation

public enum InviteCodeFormatter: Sendable {
  private static let separator: String = "-"
  private static let allowedAsciiAlphanumerics: Set<Character> = Set(
    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  )
  private static let allowedAlphabet: Set<Character> = Set(ContractConstants.inviteCodeAlphabet)

  public static func formatInput(_ raw: String) -> String {
    let filtered = raw.uppercased().filter { allowedAsciiAlphanumerics.contains($0) }
    let capped = String(filtered.prefix(ContractConstants.inviteCodeRawLength))
    guard capped.count > ContractConstants.inviteCodeGroupLength else {
      return capped
    }

    let prefix = capped.prefix(ContractConstants.inviteCodeGroupLength)
    let suffix = capped.dropFirst(ContractConstants.inviteCodeGroupLength)
    return "\(prefix)\(separator)\(suffix)"
  }

  public static func validate(_ raw: String) -> String? {
    let cleaned = raw.uppercased().filter { !$0.isWhitespace && String($0) != separator }
    guard cleaned.count == ContractConstants.inviteCodeRawLength else {
      return nil
    }

    guard cleaned.allSatisfy({ allowedAlphabet.contains($0) }) else {
      return nil
    }

    let prefix = cleaned.prefix(ContractConstants.inviteCodeGroupLength)
    let suffix = cleaned.dropFirst(ContractConstants.inviteCodeGroupLength)
    return "\(prefix)\(separator)\(suffix)"
  }
}
