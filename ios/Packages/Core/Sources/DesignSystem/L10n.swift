import Domain
import Foundation

public let designSystemBundle: Bundle = .module

public enum L10n: Sendable {
  public static let polishLocale: Locale = Locale(identifier: "pl_PL")
  public static let networkUnavailableErrorCode: String = "NETWORK_UNAVAILABLE"

  private static let photoCountKey: String = "apartments.card.photo.count"
  private static let summaryMultiTitleKey: String = "media.summary.title.multi"
  private static let errorKeyPrefix: String = "error."
  private static let networkUnavailableKey: String = "error.NETWORK_UNAVAILABLE"
  private static let unknownErrorKey: String = "error.UNKNOWN"
  private static let maxUnderlyingErrorDepth: Int = 4
  private static let missingSentinel: String = "__L10N_MISSING__"
  private static let xcstringsName: String = "Localizable"
  private static let xcstringsExtension: String = "xcstrings"

  private static let decimalTen: Int = 10
  private static let decimalHundred: Int = 100
  private static let fewRemainderMin: Int = 2
  private static let fewRemainderMax: Int = 4
  private static let teenExceptionMin: Int = 12
  private static let teenExceptionMax: Int = 14

  private static let catalogFallback: StringCatalog? = loadCatalogFallback()

  public static func string(_ key: String) -> String {
    let bundleValue = designSystemBundle.localizedString(
      forKey: key,
      value: missingSentinel,
      table: nil
    )
    if bundleValue != missingSentinel {
      return bundleValue
    }
    return catalogFallback?.strings[key]?.localizations?.pl?.stringUnit?.value ?? key
  }

  public static func format(_ key: String, _ arguments: CVarArg...) -> String {
    let formatString = string(key)
    return String(format: formatString, locale: polishLocale, arguments: arguments)
  }

  public static func photoCount(_ count: Int) -> String {
    pluralized(key: photoCountKey, count: count)
  }

  public static func summaryMultiTitle(_ count: Int) -> String {
    pluralized(key: summaryMultiTitleKey, count: count)
  }

  private static func pluralized(key: String, count: Int) -> String {
    let bundleValue = designSystemBundle.localizedString(
      forKey: key,
      value: missingSentinel,
      table: nil
    )
    if bundleValue != missingSentinel {
      return String(format: bundleValue, locale: polishLocale, count)
    }

    if let plural = catalogFallback?.strings[key]?.localizations?.pl?.variations?.plural {
      let pattern = selectPolishPlural(count: count, forms: plural) ?? key
      return String(format: pattern, locale: polishLocale, count)
    }
    return key
  }

  public static func errorMessage(for code: ServerErrorCode) -> String {
    switch code {
    case .known(let domainCode):
      return string("\(errorKeyPrefix)\(domainCode.rawValue)")
    case .unknown(let rawCode) where rawCode == networkUnavailableErrorCode:
      return string(networkUnavailableKey)
    case .unknown:
      return string(unknownErrorKey)
    }
  }

  public static func errorMessage(for code: DomainErrorCode) -> String {
    errorMessage(for: .known(code))
  }

  public static func errorMessage(for error: any Error) -> String {
    if let convertible = error as? any ServerErrorCodeConvertible {
      return errorMessage(for: convertible.serverErrorCode)
    }
    if isNetworkUnavailableError(error) {
      return string(networkUnavailableKey)
    }
    return string(unknownErrorKey)
  }

  public static func isNetworkUnavailableError(_ error: any Error) -> Bool {
    var current: (any Error)? = error
    var depth = 0
    while let candidate = current, depth < maxUnderlyingErrorDepth {
      if let urlError = candidate as? URLError, isConnectivityCode(urlError.code) {
        return true
      }
      let nsError = candidate as NSError
      let urlCode = URLError.Code(rawValue: nsError.code)
      if nsError.domain == NSURLErrorDomain, isConnectivityCode(urlCode) {
        return true
      }
      current = nsError.userInfo[NSUnderlyingErrorKey] as? any Error
      depth += 1
    }
    return false
  }

  private static func isConnectivityCode(_ code: URLError.Code) -> Bool {
    switch code {
    case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
      .networkConnectionLost, .timedOut, .dataNotAllowed, .internationalRoamingOff,
      .callIsActive, .secureConnectionFailed, .cannotLoadFromNetwork:
      return true
    default:
      return false
    }
  }

  private static func selectPolishPlural(count: Int, forms: PluralVariations) -> String? {
    let absolute = abs(count)
    if absolute == 1 {
      return forms.one?.stringUnit?.value ?? forms.other?.stringUnit?.value
    }

    let mod10 = absolute % decimalTen
    let mod100 = absolute % decimalHundred
    let isFew =
      mod10 >= fewRemainderMin && mod10 <= fewRemainderMax
      && (mod100 < teenExceptionMin || mod100 > teenExceptionMax)
    if isFew {
      return forms.few?.stringUnit?.value ?? forms.other?.stringUnit?.value
    }
    return forms.many?.stringUnit?.value ?? forms.other?.stringUnit?.value
  }

  private static func loadCatalogFallback() -> StringCatalog? {
    guard
      let url = designSystemBundle.url(
        forResource: xcstringsName,
        withExtension: xcstringsExtension
      ),
      let data = try? Data(contentsOf: url)
    else {
      return nil
    }
    return try? JSONDecoder().decode(StringCatalog.self, from: data)
  }

  private struct StringCatalog: Decodable, Sendable {
    let strings: [String: CatalogEntry]
  }

  private struct CatalogEntry: Decodable, Sendable {
    let localizations: CatalogLocalizations?
  }

  private struct CatalogLocalizations: Decodable, Sendable {
    let pl: PolishLocalization?
  }

  private struct PolishLocalization: Decodable, Sendable {
    let stringUnit: StringUnit?
    let variations: CatalogVariations?
  }

  private struct CatalogVariations: Decodable, Sendable {
    let plural: PluralVariations?
  }

  private struct PluralVariations: Decodable, Sendable {
    let one: PluralForm?
    let few: PluralForm?
    let many: PluralForm?
    let other: PluralForm?
  }

  private struct PluralForm: Decodable, Sendable {
    let stringUnit: StringUnit?
  }

  private struct StringUnit: Decodable, Sendable {
    let value: String
  }
}
