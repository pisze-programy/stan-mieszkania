import Domain
import Foundation
import SQLiteData

@Table("members")
public struct MemberRecord: Identifiable, Equatable, Hashable, Sendable {
  public let id: String
  public let apartmentId: String
  public let userId: String
  public var displayName: String
  public var shortTag: String
  public var color: String
  public var role: String
  public let joinedAt: Date
  public var leftAt: Date?

  public static func makeID(apartmentId: String, userId: String) -> String {
    "\(apartmentId)\(DatabaseConstants.memberRecordIDSeparator)\(userId)"
  }

  public init(
    id: String,
    apartmentId: String,
    userId: String,
    displayName: String,
    shortTag: String,
    color: String,
    role: String,
    joinedAt: Date,
    leftAt: Date? = nil
  ) {
    self.id = id
    self.apartmentId = apartmentId
    self.userId = userId
    self.displayName = displayName
    self.shortTag = shortTag
    self.color = color
    self.role = role
    self.joinedAt = joinedAt
    self.leftAt = leftAt
  }

  public init(apartmentId: String, member: ApartmentMember) {
    self.init(
      id: Self.makeID(apartmentId: apartmentId, userId: member.userId),
      apartmentId: apartmentId,
      userId: member.userId,
      displayName: member.displayName,
      shortTag: member.shortTag,
      color: member.color,
      role: member.role.rawValue,
      joinedAt: member.joinedAt,
      leftAt: member.leftAt
    )
  }

  public func toDomain() throws -> ApartmentMember {
    guard let memberRole = MemberRole(rawValue: role) else {
      throw AppDatabaseError.invalidStoredEnumValue(column: "members.role", value: role)
    }
    return ApartmentMember(
      userId: userId,
      displayName: displayName,
      shortTag: shortTag,
      color: color,
      role: memberRole,
      joinedAt: joinedAt,
      leftAt: leftAt
    )
  }

  public func toAuthorSummary() throws -> AuthorSummary {
    guard let memberRole = MemberRole(rawValue: role) else {
      throw AppDatabaseError.invalidStoredEnumValue(column: "members.role", value: role)
    }
    return AuthorSummary(
      userId: userId,
      displayName: displayName,
      shortTag: shortTag,
      color: color,
      role: memberRole
    )
  }
}
