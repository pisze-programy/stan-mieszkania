export interface SwiftContractConstantValues {
  readonly displayNameMinLength: number;
  readonly displayNameMaxLength: number;
  readonly apartmentNameMinLength: number;
  readonly apartmentNameMaxLength: number;
  readonly apartmentStreetMinLength: number;
  readonly apartmentStreetMaxLength: number;
  readonly apartmentCityMinLength: number;
  readonly apartmentCityMaxLength: number;
  readonly inviteCodeRawLength: number;
  readonly inviteCodeGroupLength: number;
  readonly inviteCodeAlphabet: string;
  readonly entryTextMinLength: number;
  readonly entryTextMaxLength: number;
  readonly markerCoordMin: number;
  readonly markerCoordMax: number;
  readonly sha256HexLength: number;
  readonly authorColorPalette: readonly string[];
  readonly defaultCloudMediaQuotaPerApartment: number;
  readonly defaultJpegMaxDimensionPx: number;
  readonly defaultJpegQuality: number;
  readonly defaultJpegMaxBytes: number;
  readonly defaultMinSupportedAppVersion: string;
}

function escapeSwiftString(value: string): string {
  return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}

function formatSwiftDouble(value: number): string {
  return Number.isInteger(value) ? `${String(value)}.0` : String(value);
}

function formatSwiftInt(value: number): string {
  const digits = String(Math.abs(value));
  const grouped = /^\d{5,}$/.test(digits) ? digits.replace(/\B(?=(\d{3})+(?!\d))/g, '_') : digits;
  return value < 0 ? `-${grouped}` : grouped;
}

function screamingSnakeToCamelCase(code: string): string {
  const parts = code
    .toLowerCase()
    .split('_')
    .filter((part) => part.length > 0);
  const [first, ...rest] = parts;
  if (first === undefined) {
    throw new Error(`Invalid DomainErrorCode value: ${code}`);
  }
  const capitalized = rest.map((part) => `${part.charAt(0).toUpperCase()}${part.slice(1)}`);
  return `${first}${capitalized.join('')}`;
}

export function renderContractConstantsSwift(values: SwiftContractConstantValues): string {
  const intFields: readonly [string, number][] = [
    ['displayNameMinLength', values.displayNameMinLength],
    ['displayNameMaxLength', values.displayNameMaxLength],
    ['apartmentNameMinLength', values.apartmentNameMinLength],
    ['apartmentNameMaxLength', values.apartmentNameMaxLength],
    ['apartmentStreetMinLength', values.apartmentStreetMinLength],
    ['apartmentStreetMaxLength', values.apartmentStreetMaxLength],
    ['apartmentCityMinLength', values.apartmentCityMinLength],
    ['apartmentCityMaxLength', values.apartmentCityMaxLength],
    ['inviteCodeRawLength', values.inviteCodeRawLength],
    ['inviteCodeGroupLength', values.inviteCodeGroupLength],
    ['entryTextMinLength', values.entryTextMinLength],
    ['entryTextMaxLength', values.entryTextMaxLength],
    ['sha256HexLength', values.sha256HexLength],
    ['defaultCloudMediaQuotaPerApartment', values.defaultCloudMediaQuotaPerApartment],
    ['defaultJpegMaxDimensionPx', values.defaultJpegMaxDimensionPx],
    ['defaultJpegMaxBytes', values.defaultJpegMaxBytes],
  ];

  const palette = values.authorColorPalette
    .map((hex) => `    "${escapeSwiftString(hex)}",`)
    .join('\n');

  const lines = [
    'import Foundation',
    '',
    'public enum ContractConstants: Sendable {',
    ...intFields.map(([name, val]) => `  public static let ${name}: Int = ${formatSwiftInt(val)}`),
    `  public static let inviteCodeAlphabet: String = "${escapeSwiftString(values.inviteCodeAlphabet)}"`,
    `  public static let markerCoordMin: Double = ${formatSwiftDouble(values.markerCoordMin)}`,
    `  public static let markerCoordMax: Double = ${formatSwiftDouble(values.markerCoordMax)}`,
    '  public static let authorColorPalette: [String] = [',
    palette,
    '  ]',
    `  public static let defaultJpegQuality: Double = ${formatSwiftDouble(values.defaultJpegQuality)}`,
    `  public static let defaultMinSupportedAppVersion: String = "${escapeSwiftString(values.defaultMinSupportedAppVersion)}"`,
    '}',
    '',
  ];
  return lines.join('\n');
}

export function renderDomainErrorCodeSwift(codes: readonly string[]): string {
  const sortedCodes = [...codes].sort();
  const seenCaseNames = new Set<string>();
  const caseLines = sortedCodes.map((raw) => {
    const caseName = screamingSnakeToCamelCase(raw);
    if (seenCaseNames.has(caseName)) {
      throw new Error(`Duplicate Swift case name derived for DomainErrorCode: ${caseName}`);
    }
    seenCaseNames.add(caseName);
    return `  case ${caseName} = "${escapeSwiftString(raw)}"`;
  });

  return `import Foundation

public enum DomainErrorCode: String, Codable, Sendable, CaseIterable, Equatable {
${caseLines.join('\n')}
}

public enum ServerErrorCode: Sendable, Equatable, Codable {
  case known(DomainErrorCode)
  case unknown(String)

  public init(rawValue: String) {
    if let knownCode = DomainErrorCode(rawValue: rawValue) {
      self = .known(knownCode)
    } else {
      self = .unknown(rawValue)
    }
  }

  public var rawValue: String {
    switch self {
    case .known(let knownCode):
      return knownCode.rawValue
    case .unknown(let rawCode):
      return rawCode
    }
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self.init(rawValue: rawValue)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
`;
}
