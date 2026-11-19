import Foundation

public enum AuthClientConstants: Sendable {
  public static let localDevTokenPrefix: String = "dev:"
  public static let localDevSeparator: String = ":"
  public static let keychainService: String = "pl.stanmieszkania.app.auth"
  public static let keychainAccount: String = "active-session"
  public static let appleNonceLength: Int = 32
  public static let firebaseRefreshLeewaySeconds: TimeInterval = 300
  public static let defaultTokenExpirySeconds: TimeInterval = 3_600
  public static let googleServiceInfoResourceName: String = "GoogleService-Info"
  public static let googleServiceInfoExtension: String = "plist"
  public static let googleServiceApiKeyPlistKey: String = "API_KEY"
  public static let firebaseWebApiKeyInfoKey: String = "FIREBASE_WEB_API_KEY"
  public static let placeholderValuePrefix: String = "REPLACE_WITH_"
  public static let xcconfigUnexpandedPrefix: String = "$("
  public static let firebaseIdentityToolkitBaseURL: String =
    "https://identitytoolkit.googleapis.com/v1"
  public static let firebaseSecureTokenBaseURL: String = "https://securetoken.googleapis.com/v1"
  public static let appleProviderId: String = "apple.com"
  public static let defaultRequestUri: String = "http://localhost"
  public static let httpStatusSuccessLower: Int = 200
  public static let httpStatusSuccessUpper: Int = 299
  public static let unreservedURLCharacters: CharacterSet = {
    var set = CharacterSet.alphanumerics
    set.insert(charactersIn: "-_.~")
    return set
  }()
}
