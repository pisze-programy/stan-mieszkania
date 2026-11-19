import DesignSystem
import Domain
import Foundation

public enum MediaSummarySaveMode: Equatable, Sendable {
  case localOnly
  case cloud
}

public struct SummaryDraftMarker: Identifiable, Equatable, Hashable, Sendable {
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

public struct MediaSummaryPageState: Identifiable, Equatable, Sendable {
  public let draft: CapturedPhotoDraft
  public var description: String
  public var markers: [SummaryDraftMarker]
  public var selectedMarkerNumber: Int?

  public var id: String { draft.id }

  public init(
    draft: CapturedPhotoDraft,
    description: String = "",
    markers: [SummaryDraftMarker] = [],
    selectedMarkerNumber: Int? = nil
  ) {
    self.draft = draft
    self.description = description
    self.markers = markers
    self.selectedMarkerNumber = selectedMarkerNumber
  }

  public func markerOverlayItems() -> [MarkerOverlayItem] {
    markers.map { $0.toOverlayItem() }
  }
}

struct ValidatedSummaryPage: Equatable, Sendable {
  let draft: CapturedPhotoDraft
  let initialEntryText: String?
  let markers: [SummaryDraftMarker]
}

struct SummaryValidationFailure: Error, Equatable {
  let message: String
}
