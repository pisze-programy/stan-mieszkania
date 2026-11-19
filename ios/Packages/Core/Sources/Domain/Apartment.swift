import Foundation

public struct Apartment: Identifiable, Codable, Sendable, Equatable, Hashable {
  public let id: String
  public let ownerId: String
  public var name: String
  public var street: String
  public var city: String
  public let role: MemberRole
  public var inviteCode: String?
  public var shouldSuggestInviteCodeReset: Bool
  public var cloudMediaCount: Int
  public let createdAt: Date
  public var updatedAt: Date

  public init(
    id: String,
    ownerId: String,
    name: String,
    street: String,
    city: String,
    role: MemberRole,
    inviteCode: String? = nil,
    shouldSuggestInviteCodeReset: Bool = false,
    cloudMediaCount: Int = 0,
    createdAt: Date,
    updatedAt: Date
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
  }
}

public enum ApartmentEditableField: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
  case name
  case street
  case city
}

public struct ApartmentChange: Identifiable, Codable, Sendable, Equatable, Hashable {
  public let id: String
  public let apartmentId: String
  public let authorId: String
  public let field: ApartmentEditableField
  public let oldValue: String
  public let newValue: String
  public let createdAt: Date

  public init(
    id: String,
    apartmentId: String,
    authorId: String,
    field: ApartmentEditableField,
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
}
