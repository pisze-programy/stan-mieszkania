import Domain
import Foundation
import SQLiteData

@Table("apartments")
public struct ApartmentRecord: Identifiable, Equatable, Hashable, Sendable {
  public let id: String
  public var ownerId: String
  public var name: String
  public var street: String
  public var city: String
  public var role: String
  public var inviteCode: String?
  public var shouldSuggestInviteCodeReset: Bool
  public var cloudMediaCount: Int
  public let createdAt: Date
  public var updatedAt: Date
  public var deletedAt: Date?

  public init(
    id: String,
    ownerId: String,
    name: String,
    street: String,
    city: String,
    role: String,
    inviteCode: String? = nil,
    shouldSuggestInviteCodeReset: Bool = false,
    cloudMediaCount: Int = 0,
    createdAt: Date,
    updatedAt: Date,
    deletedAt: Date? = nil
  ) {
    self.id = id
    self.ownerId = ownerId
    self.name = name
    self.street = street
    self.city = city
    self.role = role
    self.inviteCode = inviteCode
    self.shouldSuggestInviteCodeReset = shouldSuggestInviteCodeReset
    self.cloudMediaCount = cloudMediaCount
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.deletedAt = deletedAt
  }

  public init(apartment: Apartment, deletedAt: Date? = nil) {
    self.init(
      id: apartment.id,
      ownerId: apartment.ownerId,
      name: apartment.name,
      street: apartment.street,
      city: apartment.city,
      role: apartment.role.rawValue,
      inviteCode: apartment.inviteCode,
      shouldSuggestInviteCodeReset: apartment.shouldSuggestInviteCodeReset,
      cloudMediaCount: apartment.cloudMediaCount,
      createdAt: apartment.createdAt,
      updatedAt: apartment.updatedAt,
      deletedAt: deletedAt
    )
  }

  public func toDomain() throws -> Apartment {
    guard let memberRole = MemberRole(rawValue: role) else {
      throw AppDatabaseError.invalidStoredEnumValue(column: "apartments.role", value: role)
    }
    return Apartment(
      id: id,
      ownerId: ownerId,
      name: name,
      street: street,
      city: city,
      role: memberRole,
      inviteCode: inviteCode,
      shouldSuggestInviteCodeReset: shouldSuggestInviteCodeReset,
      cloudMediaCount: cloudMediaCount,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}

@Table("apartment_changes")
public struct ApartmentChangeRecord: Identifiable, Equatable, Hashable, Sendable {
  public let id: String
  public let apartmentId: String
  public let authorId: String
  public let field: String
  public let oldValue: String
  public let newValue: String
  public let createdAt: Date

  public init(
    id: String,
    apartmentId: String,
    authorId: String,
    field: String,
    oldValue: String,
    newValue: String,
    createdAt: Date
  ) {
    self.id = id
    self.apartmentId = apartmentId
    self.authorId = authorId
    self.field = field
    self.oldValue = oldValue
    self.newValue = newValue
    self.createdAt = createdAt
  }

  public init(change: ApartmentChange) {
    self.init(
      id: change.id,
      apartmentId: change.apartmentId,
      authorId: change.authorId,
      field: change.field.rawValue,
      oldValue: change.oldValue,
      newValue: change.newValue,
      createdAt: change.createdAt
    )
  }

  public func toDomain() throws -> ApartmentChange {
    guard let editableField = ApartmentEditableField(rawValue: field) else {
      throw AppDatabaseError.invalidStoredEnumValue(
        column: "apartment_changes.field",
        value: field
      )
    }
    return ApartmentChange(
      id: id,
      apartmentId: apartmentId,
      authorId: authorId,
      field: editableField,
      oldValue: oldValue,
      newValue: newValue,
      createdAt: createdAt
    )
  }
}
