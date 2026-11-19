import Domain
import Foundation

public typealias CaptureSource = CaptureSourceKind

public enum LeaveOrDeleteMode: Equatable, Sendable {
  case ownerDeleteOrLeave
  case contributorLeave
}

public struct TimelineMediaItem: Identifiable, Equatable, Sendable {
  public let media: MediaItem
  public let authorDisplayName: String
  public let authorColorHex: String
  public let authorRole: MemberRole?

  public var id: String { media.id }

  public init(
    media: MediaItem,
    authorDisplayName: String,
    authorColorHex: String,
    authorRole: MemberRole? = nil
  ) {
    self.media = media
    self.authorDisplayName = authorDisplayName
    self.authorColorHex = authorColorHex
    self.authorRole = authorRole
  }
}

public struct TimelineDaySection: Identifiable, Equatable, Sendable {
  public let dayKey: String
  public let title: String
  public let items: [TimelineMediaItem]

  public var id: String { dayKey }

  public init(dayKey: String, title: String, items: [TimelineMediaItem]) {
    self.dayKey = dayKey
    self.title = title
    self.items = items
  }
}

public struct ApartmentTimelineSnapshot: Equatable, Sendable {
  public let apartment: Apartment?
  public let sections: [TimelineDaySection]
  public let localUnsyncedCount: Int
  public let cloudMediaCount: Int
  public let showsAuthor: Bool
  public let hasOtherMembers: Bool

  public init(
    apartment: Apartment?,
    sections: [TimelineDaySection],
    localUnsyncedCount: Int,
    cloudMediaCount: Int,
    showsAuthor: Bool = false,
    hasOtherMembers: Bool = false
  ) {
    self.apartment = apartment
    self.sections = sections
    self.localUnsyncedCount = localUnsyncedCount
    self.cloudMediaCount = cloudMediaCount
    self.showsAuthor = showsAuthor
    self.hasOtherMembers = hasOtherMembers
  }
}

public struct EditApartmentSheetState: Identifiable, Equatable, Sendable {
  public var name: String
  public var street: String
  public var city: String
  public var isSaving: Bool
  public var errorMessage: String?

  public var id: String { ApartmentTimelineConstants.editSheetID }

  public var isValid: Bool {
    if case .success = ApartmentTimelineStore.validateEditInput(
      name: name,
      street: street,
      city: city
    ) {
      return true
    }
    return false
  }

  public init(
    name: String,
    street: String,
    city: String,
    isSaving: Bool = false,
    errorMessage: String? = nil
  ) {
    self.name = name
    self.street = street
    self.city = city
    self.isSaving = isSaving
    self.errorMessage = errorMessage
  }
}

public struct ApartmentHistorySheetState: Identifiable, Equatable, Sendable {
  public var changes: [ApartmentChange]
  public var authorNames: [String: String]
  public var isLoading: Bool
  public var errorMessage: String?

  public var id: String { ApartmentTimelineConstants.historySheetID }

  public init(
    changes: [ApartmentChange] = [],
    authorNames: [String: String] = [:],
    isLoading: Bool = false,
    errorMessage: String? = nil
  ) {
    self.changes = changes
    self.authorNames = authorNames
    self.isLoading = isLoading
    self.errorMessage = errorMessage
  }
}

public struct ValidatedApartmentEdit: Equatable, Sendable {
  public let name: String
  public let street: String
  public let city: String
}

struct TimelineValidationFailure: Error, Equatable {
  let message: String
}
