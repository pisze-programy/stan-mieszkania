import Foundation

public enum MemberRole: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
  case owner
  case contributor
}

public struct UserProfile: Identifiable, Codable, Sendable, Equatable, Hashable {
  public let id: String
  public var displayName: String
  public let shortTag: String
  public let color: String
  public let createdAt: Date

  public var hasCustomDisplayName: Bool {
    !displayName.hasPrefix("\(DomainConstants.fallbackUserDisplayPrefix) #")
  }

  public init(
    id: String,
    displayName: String,
    shortTag: String,
    color: String,
    createdAt: Date
  ) {
    self.id = id
    self.displayName = displayName
    self.shortTag = shortTag
    self.color = color
    self.createdAt = createdAt
  }
}

public struct AuthorSummary: Codable, Sendable, Equatable, Hashable {
  public let userId: String
  public let displayName: String
  public let shortTag: String
  public let color: String
  public let role: MemberRole

  public init(
    userId: String,
    displayName: String,
    shortTag: String,
    color: String,
    role: MemberRole
  ) {
    self.userId = userId
    self.displayName = displayName
    self.shortTag = shortTag
    self.color = color
    self.role = role
  }
}

public struct ApartmentMember: Identifiable, Codable, Sendable, Equatable, Hashable {
  public let userId: String
  public var displayName: String
  public let shortTag: String
  public let color: String
  public let role: MemberRole
  public let joinedAt: Date
  public let leftAt: Date?

  public var id: String { userId }
  public var isActive: Bool { leftAt == nil }

  public init(
    userId: String,
    displayName: String,
    shortTag: String,
    color: String,
    role: MemberRole,
    joinedAt: Date,
    leftAt: Date? = nil
  ) {
    self.userId = userId
    self.displayName = displayName
    self.shortTag = shortTag
    self.color = color
    self.role = role
    self.joinedAt = joinedAt
    self.leftAt = leftAt
  }
}
