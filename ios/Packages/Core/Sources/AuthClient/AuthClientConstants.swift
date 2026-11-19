import Foundation

public enum AuthClientConstants: Sendable {
  public static let localDevTokenPrefix: String = "dev:"
  public static let localDevSeparator: String = ":"
  public static let keychainService: String = "pl.stanmieszkania.app.auth"
  public static let keychainAccount: String = "active-session"
  public static let unreservedURLCharacters: CharacterSet = {
    var set = CharacterSet.alphanumerics
    set.insert(charactersIn: "-_.~")
    return set
  }()
}
