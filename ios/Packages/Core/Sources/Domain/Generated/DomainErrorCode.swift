import Foundation

public enum DomainErrorCode: String, Codable, Sendable, CaseIterable, Equatable {
  case accountDeletionFailed = "ACCOUNT_DELETION_FAILED"
  case apartmentAccessDenied = "APARTMENT_ACCESS_DENIED"
  case apartmentNotFound = "APARTMENT_NOT_FOUND"
  case apartmentOwnerRequired = "APARTMENT_OWNER_REQUIRED"
  case apartmentValidationFailed = "APARTMENT_VALIDATION_FAILED"
  case appUpdateRequired = "APP_UPDATE_REQUIRED"
  case authTokenInvalid = "AUTH_TOKEN_INVALID"
  case authTokenMissing = "AUTH_TOKEN_MISSING"
  case cannotRevokeOwner = "CANNOT_REVOKE_OWNER"
  case conflict = "CONFLICT"
  case displayNameInvalid = "DISPLAY_NAME_INVALID"
  case entryAccessDenied = "ENTRY_ACCESS_DENIED"
  case entryAlreadyRetracted = "ENTRY_ALREADY_RETRACTED"
  case entryAuthorRequired = "ENTRY_AUTHOR_REQUIRED"
  case entryConflict = "ENTRY_CONFLICT"
  case entryMediaNotReady = "ENTRY_MEDIA_NOT_READY"
  case entryNotFound = "ENTRY_NOT_FOUND"
  case entryValidationFailed = "ENTRY_VALIDATION_FAILED"
  case externalAuthCleanupFailed = "EXTERNAL_AUTH_CLEANUP_FAILED"
  case forbidden = "FORBIDDEN"
  case internalError = "INTERNAL_ERROR"
  case invalidAppleAuthorizationCode = "INVALID_APPLE_AUTHORIZATION_CODE"
  case inviteCodeCollision = "INVITE_CODE_COLLISION"
  case inviteCodeInvalid = "INVITE_CODE_INVALID"
  case inviteCodeNotFound = "INVITE_CODE_NOT_FOUND"
  case inviteCodeRateLimited = "INVITE_CODE_RATE_LIMITED"
  case markerDuplicateLocalNumber = "MARKER_DUPLICATE_LOCAL_NUMBER"
  case markerInvalidCoordinates = "MARKER_INVALID_COORDINATES"
  case mediaAccessDenied = "MEDIA_ACCESS_DENIED"
  case mediaAlreadyDeleted = "MEDIA_ALREADY_DELETED"
  case mediaAuthorRequired = "MEDIA_AUTHOR_REQUIRED"
  case mediaConflict = "MEDIA_CONFLICT"
  case mediaHashMismatch = "MEDIA_HASH_MISMATCH"
  case mediaInvalidSha256 = "MEDIA_INVALID_SHA256"
  case mediaNotFound = "MEDIA_NOT_FOUND"
  case mediaObjectNotUploaded = "MEDIA_OBJECT_NOT_UPLOADED"
  case mediaValidationFailed = "MEDIA_VALIDATION_FAILED"
  case membershipAccessDenied = "MEMBERSHIP_ACCESS_DENIED"
  case membershipNotFound = "MEMBERSHIP_NOT_FOUND"
  case membershipOwnerRequired = "MEMBERSHIP_OWNER_REQUIRED"
  case notFound = "NOT_FOUND"
  case quotaExceeded = "QUOTA_EXCEEDED"
  case rateLimited = "RATE_LIMITED"
  case routeNotFound = "ROUTE_NOT_FOUND"
  case syncAccessDenied = "SYNC_ACCESS_DENIED"
  case syncApartmentNotFound = "SYNC_APARTMENT_NOT_FOUND"
  case syncValidationFailed = "SYNC_VALIDATION_FAILED"
  case unauthorized = "UNAUTHORIZED"
  case unprocessableEntity = "UNPROCESSABLE_ENTITY"
  case userDeleted = "USER_DELETED"
  case userNotFound = "USER_NOT_FOUND"
  case validationError = "VALIDATION_ERROR"
  case videoDisabledInMvp = "VIDEO_DISABLED_IN_MVP"
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
