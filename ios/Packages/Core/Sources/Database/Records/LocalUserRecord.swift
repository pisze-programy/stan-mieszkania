import Domain
import Foundation
import SQLiteData

@Table("local_users")
public struct LocalUserRecord: Identifiable, Equatable, Hashable, Sendable {
  public let id: String
  public var displayName: String
  public let shortTag: String
  public let color: String
  public let createdAt: Date
  public var isCurrentUser: Bool

  public init(
    id: String,
    displayName: String,
    shortTag: String,
    color: String,
    createdAt: Date,
    isCurrentUser: Bool = true
  ) {
    self.id = id
    self.displayName = displayName
    self.shortTag = shortTag
    self.color = color
    self.createdAt = createdAt
    self.isCurrentUser = isCurrentUser
  }

  public init(profile: UserProfile, isCurrentUser: Bool = true) {
    self.init(
      id: profile.id,
      displayName: profile.displayName,
      shortTag: profile.shortTag,
      color: profile.color,
      createdAt: profile.createdAt,
      isCurrentUser: isCurrentUser
    )
  }

  public func toDomain() -> UserProfile {
    UserProfile(
      id: id,
      displayName: displayName,
      shortTag: shortTag,
      color: color,
      createdAt: createdAt
    )
  }
}
