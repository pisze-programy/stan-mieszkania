import DesignSystem
import Domain
import Foundation

extension MediaDetailFeature.State {
  public var isMediaAuthor: Bool {
    guard let media, let userId = currentUser?.userId else {
      return false
    }
    return media.authorId == userId
  }

  // Invariant 7 & S2-2: Any active member may append to verified media; authors may append to own local media.
  public var canComposeEntry: Bool {
    guard let media, !media.isSoftDeleted, let userId = currentUser?.userId else {
      return false
    }
    return media.isVerified || media.authorId == userId
  }

  public var canUploadToCloud: Bool {
    guard let media else {
      return false
    }
    return isMediaAuthor && !media.isSoftDeleted && media.serverReceivedAt == nil
      && media.syncState == .localOnly
  }

  public var canDeleteMedia: Bool {
    guard let media, !media.isSoftDeleted else {
      return false
    }
    return isMediaAuthor
  }

  public var maxExistingMarkerNumber: Int {
    let excludedEntryId = composer?.editingEntryId
    let existingNumbers = entries.flatMap { item -> [Int] in
      guard !item.entry.isRetracted, item.id != excludedEntryId else {
        return []
      }
      return item.entry.markers.map(\.number)
    }
    return existingNumbers.max() ?? 0
  }

  public var overlayMarkers: [MarkerOverlayItem] {
    let excludedEntryId = composer?.editingEntryId
    var items: [MarkerOverlayItem] = []

    for entryItem in entries {
      guard !entryItem.entry.isRetracted, entryItem.id != excludedEntryId else {
        continue
      }
      for marker in entryItem.entry.markers {
        items.append(
          MarkerOverlayItem(
            id: marker.id,
            number: marker.number,
            x: marker.x,
            y: marker.y,
            authorColorHex: entryItem.authorColorHex
          )
        )
      }
    }

    if let composer {
      let draftColor = currentUser?.color ?? DomainConstants.defaultAuthorColor
      for draftMarker in composer.markers {
        items.append(draftMarker.toOverlayItem(authorColorHex: draftColor))
      }
    }

    return items
  }

  public func entryId(owningMarker number: Int) -> String? {
    entries.first { item in
      !item.entry.isRetracted && item.entry.markers.contains { $0.number == number }
    }?.id
  }

  // Invariant 3 & Q4: Local unsynced entries are editable/hard-deletable only by their author.
  public func canEditOrHardDeleteEntry(_ item: MediaDetailEntryItem) -> Bool {
    guard let userId = currentUser?.userId else {
      return false
    }
    return item.entry.authorId == userId && !item.entry.isVerified && !item.entry.isRetracted
  }

  // Invariant 3 & Q4: Synced entries are immutable and retractable only by their author.
  public func canRetractEntry(_ item: MediaDetailEntryItem) -> Bool {
    guard let userId = currentUser?.userId else {
      return false
    }
    return item.entry.authorId == userId && item.entry.isVerified && !item.entry.isRetracted
  }
}
