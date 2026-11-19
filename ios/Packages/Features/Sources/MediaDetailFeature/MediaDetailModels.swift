import DesignSystem
import Domain
import Foundation

public struct DetailDraftMarker: Identifiable, Equatable, Hashable, Sendable {
  public let id: String
  public let number: Int
  public let x: Double
  public let y: Double

  public init(id: String, number: Int, x: Double, y: Double) {
    self.id = id
    self.number = number
    self.x = x
    self.y = y
  }

  public func toOverlayItem() -> MarkerOverlayItem {
    MarkerOverlayItem(
      id: id,
      number: number,
      x: x,
      y: y,
      colorHex: MarkerPalette.hex(forMarkerNumber: number)
    )
  }

  public func toMarkerPoint(entryId: String, mediaId: String) -> MarkerPoint {
    MarkerPoint(
      id: id,
      entryId: entryId,
      mediaId: mediaId,
      number: number,
      isServerAssigned: false,
      x: x,
      y: y
    )
  }
}

public struct MediaDetailEntryItem: Identifiable, Equatable, Sendable {
  public let entry: EntryItem
  public let authorDisplayName: String
  public let authorColorHex: String
  public let authorRole: MemberRole?

  public var id: String { entry.id }

  public init(
    entry: EntryItem,
    authorDisplayName: String,
    authorColorHex: String,
    authorRole: MemberRole?
  ) {
    self.entry = entry
    self.authorDisplayName = authorDisplayName
    self.authorColorHex = authorColorHex
    self.authorRole = authorRole
  }
}

public struct MediaDetailSnapshot: Equatable, Sendable {
  public let media: MediaItem?
  public let mediaAuthorName: String
  public let mediaAuthorColorHex: String
  public let entries: [MediaDetailEntryItem]
  public let currentUser: AuthorSummary?
  public let hasOtherMembers: Bool

  public init(
    media: MediaItem?,
    mediaAuthorName: String,
    mediaAuthorColorHex: String,
    entries: [MediaDetailEntryItem],
    currentUser: AuthorSummary?,
    hasOtherMembers: Bool = false
  ) {
    self.media = media
    self.mediaAuthorName = mediaAuthorName
    self.mediaAuthorColorHex = mediaAuthorColorHex
    self.entries = entries
    self.currentUser = currentUser
    self.hasOtherMembers = hasOtherMembers
  }
}

public struct LightboxMarkerCaption: Equatable, Sendable {
  public let markerNumber: Int
  public let entryText: String
  public let linkedMarkerNumbers: Set<Int>
  public let authorDisplayName: String
  public let authorShortTag: String?
  public let createdAt: Date

  public init(
    markerNumber: Int,
    entryText: String,
    linkedMarkerNumbers: Set<Int> = [],
    authorDisplayName: String,
    authorShortTag: String?,
    createdAt: Date
  ) {
    self.markerNumber = markerNumber
    self.entryText = entryText
    self.linkedMarkerNumbers = linkedMarkerNumbers
    self.authorDisplayName = authorDisplayName
    self.authorShortTag = authorShortTag
    self.createdAt = createdAt
  }

  public func formattedAuthorLine(referenceDate: Date) -> String {
    let formattedDate = PolishDateFormatters.formatHumanTimestamp(createdAt, now: referenceDate)
    let fallbackPrefix = "\(DomainConstants.fallbackUserDisplayPrefix) #"
    if let shortTag = authorShortTag {
      let shouldAppend =
        !shortTag.isEmpty
        && !authorDisplayName.hasPrefix(fallbackPrefix)
        && !authorDisplayName.hasSuffix("#\(shortTag)")
      if shouldAppend {
        return "\(authorDisplayName) #\(shortTag) · \(formattedDate)"
      }
    }
    return "\(authorDisplayName) · \(formattedDate)"
  }
}

public struct EntryComposerState: Equatable, Sendable {
  public var editingEntryId: String?
  public var text: String
  public var markers: [DetailDraftMarker]
  public var isSubmitting: Bool
  public var errorMessage: String?

  public var activeMarkers: [DetailDraftMarker] {
    let referenced = MarkerTextPolicy.referencedMarkerNumbers(in: text)
    return markers.filter { referenced.contains($0.number) }
  }

  public init(
    editingEntryId: String? = nil,
    text: String = "",
    markers: [DetailDraftMarker] = [],
    isSubmitting: Bool = false,
    errorMessage: String? = nil
  ) {
    self.editingEntryId = editingEntryId
    self.text = text
    self.markers = markers
    self.isSubmitting = isSubmitting
    self.errorMessage = errorMessage
  }
}

public enum MediaDeleteConfirmationMode: Equatable, Sendable {
  case hardDeleteLocal
  case softDeleteSynced
}

public enum EntryDeleteConfirmation: Equatable, Sendable {
  case hardDeleteLocal(entryId: String)
  case retractSynced(entryId: String)

  public var entryId: String {
    switch self {
    case .hardDeleteLocal(let entryId), .retractSynced(let entryId):
      return entryId
    }
  }
}

struct DetailValidationFailure: Error, Equatable {
  let message: String
}
