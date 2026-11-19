import Foundation

public typealias AuthHTTPTransport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

public struct FirebaseAuthConfiguration: Equatable, Sendable {
  public let apiKey: String

  public init(apiKey: String) {
    self.apiKey = apiKey
  }

  public static func load(from bundle: Bundle = .main) -> Self? {
    if let plistKey = loadFromGoogleServicePlist(in: bundle) {
      return Self(apiKey: plistKey)
    }
    if let infoKey = normalizeKey(
      bundle.object(forInfoDictionaryKey: AuthClientConstants.firebaseWebApiKeyInfoKey) as? String
    ) {
      return Self(apiKey: infoKey)
    }
    return nil
  }

  private static func loadFromGoogleServicePlist(in bundle: Bundle) -> String? {
    guard
      let url = bundle.url(
        forResource: AuthClientConstants.googleServiceInfoResourceName,
        withExtension: AuthClientConstants.googleServiceInfoExtension
      ),
      let dictionary = NSDictionary(contentsOf: url) as? [String: Any],
      let rawKey = dictionary[AuthClientConstants.googleServiceApiKeyPlistKey] as? String
    else {
      return nil
    }
    return normalizeKey(rawKey)
  }

  static func normalizeKey(_ rawValue: String?) -> String? {
    guard let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty
    else {
      return nil
    }
    let isPlaceholder = trimmed.hasPrefix(AuthClientConstants.placeholderValuePrefix)
    let isUnexpanded = trimmed.hasPrefix(AuthClientConstants.xcconfigUnexpandedPrefix)
    guard !isPlaceholder, !isUnexpanded else {
      return nil
    }
    return trimmed
  }
}

struct SignInWithIdpRequest: Encodable, Sendable {
  let postBody: String
  let requestUri: String
  let returnIdpCredential: Bool
  let returnSecureToken: Bool
}

struct SignInWithIdpResponse: Decodable, Sendable {
  let localId: String
  let idToken: String
  let refreshToken: String
  let expiresIn: String
  let displayName: String?
  let fullName: String?
}

struct UpdateAccountRequest: Encodable, Sendable {
  let idToken: String
  let displayName: String
  let returnSecureToken: Bool
}

struct SecureTokenRefreshResponse: Decodable, Sendable {
  let idToken: String
  let refreshToken: String
  let expiresIn: String
  let userId: String

  enum CodingKeys: String, CodingKey {
    case idToken = "id_token"
    case refreshToken = "refresh_token"
    case expiresIn = "expires_in"
    case userId = "user_id"
  }
}

struct FirebaseAPIErrorEnvelope: Decodable, Sendable {
  struct Detail: Decodable, Sendable {
    let message: String?
  }

  let error: Detail?
}

enum FirebaseRequestHelpers {
  static func buildURL(base: String, path: String, apiKey: String) throws -> URL {
    guard var components = URLComponents(string: "\(base)\(path)") else {
      throw AuthClientError.encodingFailed
    }
    components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
    guard let url = components.url else {
      throw AuthClientError.encodingFailed
    }
    return url
  }

  static func formEncode(_ pairs: [(String, String)]) throws -> String {
    try pairs.map { key, value in
      guard
        let encodedKey = key.addingPercentEncoding(
          withAllowedCharacters: AuthClientConstants.unreservedURLCharacters
        ),
        let encodedValue = value.addingPercentEncoding(
          withAllowedCharacters: AuthClientConstants.unreservedURLCharacters
        )
      else {
        throw AuthClientError.encodingFailed
      }
      return "\(encodedKey)=\(encodedValue)"
    }.joined(separator: "&")
  }

  static func validateStatus(
    _ response: HTTPURLResponse,
    data: Data,
    makeError: (Int, String) -> AuthClientError
  ) throws {
    let range =
      AuthClientConstants.httpStatusSuccessLower...AuthClientConstants.httpStatusSuccessUpper
    guard range.contains(response.statusCode) else {
      let decoded = try? JSONDecoder().decode(FirebaseAPIErrorEnvelope.self, from: data)
      let message = decoded?.error?.message ?? "HTTP \(response.statusCode)"
      throw makeError(response.statusCode, message)
    }
  }

  static func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    do {
      return try JSONDecoder().decode(type, from: data)
    } catch {
      throw AuthClientError.invalidCredential("Unable to decode Firebase response")
    }
  }

  static func normalizedName(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty
    else {
      return nil
    }
    return trimmed
  }
}
