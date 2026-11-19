import Domain
import Foundation

enum CoreSchemaMappers: Sendable {
  static func mapConfig(_ wire: Components.Schemas.PublicAppConfig) -> AppRuntimeConfig {
    AppRuntimeConfig(
      minSupportedAppVersion: wire.minSupportedAppVersion,
      cloudMediaQuotaPerApartment: wire.cloudMediaQuotaPerApartment,
      jpegCompression: JpegCompressionSettings(
        maxDimensionPx: wire.jpegCompression.maxDimensionPx,
        quality: wire.jpegCompression.quality,
        maxBytes: wire.jpegCompression.maxBytes
      )
    )
  }

  static func mapUserProfile(_ wire: Components.Schemas.UserProfile) -> UserProfile {
    UserProfile(
      id: wire.id,
      displayName: wire.displayName,
      shortTag: wire.shortTag,
      color: wire.color,
      createdAt: wire.createdAt
    )
  }

  static func mapRole(_ wire: Components.Schemas.ApartmentRole) -> MemberRole {
    switch wire {
    case .owner:
      return .owner
    case .contributor:
      return .contributor
    }
  }

  static func mapApartment(_ wire: Components.Schemas.Apartment) -> Apartment {
    Apartment(
      id: wire.id,
      ownerId: wire.ownerId,
      name: wire.name,
      street: wire.street,
      city: wire.city,
      role: mapRole(wire.role),
      inviteCode: wire.inviteCode,
      shouldSuggestInviteCodeReset: wire.shouldSuggestInviteCodeReset,
      cloudMediaCount: wire.cloudMediaCount,
      createdAt: wire.createdAt,
      updatedAt: wire.updatedAt
    )
  }

  static func mapApartmentChange(
    _ wire: Components.Schemas.ApartmentChange
  ) -> ApartmentChange {
    let field: ApartmentEditableField
    switch wire.field {
    case .name:
      field = .name
    case .street:
      field = .street
    case .city:
      field = .city
    }
    return ApartmentChange(
      id: wire.id,
      apartmentId: wire.apartmentId,
      authorId: wire.authorId,
      field: field,
      oldValue: wire.oldValue,
      newValue: wire.newValue,
      createdAt: wire.createdAt
    )
  }

  static func mapApartmentMember(
    _ wire: Components.Schemas.ApartmentMember
  ) -> ApartmentMember {
    ApartmentMember(
      userId: wire.userId,
      displayName: wire.displayName,
      shortTag: wire.shortTag,
      color: wire.color,
      role: mapRole(wire.role),
      joinedAt: wire.joinedAt,
      leftAt: wire.leftAt?.value1
    )
  }

  static func mapSyncActor(_ wire: Components.Schemas.SyncActorSummary) -> AuthorSummary {
    AuthorSummary(
      userId: wire.userId,
      displayName: wire.displayName,
      shortTag: wire.shortTag,
      color: wire.color,
      role: mapRole(wire.role)
    )
  }
}
