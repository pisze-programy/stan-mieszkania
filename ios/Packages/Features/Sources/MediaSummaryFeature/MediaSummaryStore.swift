import Database
import DesignSystem
import Domain
import Foundation
import SQLiteData

struct PersistSummaryRequest: Sendable {
  let pages: [ValidatedSummaryPage]
  let apartmentId: String
  let currentUser: AuthorSummary
  let mode: MediaSummarySaveMode
  let idGenerator: any IDGenerator
  let now: Date
}

enum MediaSummaryStore {
  static func validatePages(
    _ pages: [MediaSummaryPageState]
  ) -> Result<[ValidatedSummaryPage], SummaryValidationFailure> {
    guard !pages.isEmpty else {
      return .failure(
        SummaryValidationFailure(message: L10n.errorMessage(for: .mediaValidationFailed))
      )
    }

    var validated: [ValidatedSummaryPage] = []
    validated.reserveCapacity(pages.count)

    for page in pages {
      let trimmed = page.description.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.count > ContractConstants.entryTextMaxLength {
        return .failure(
          SummaryValidationFailure(message: L10n.errorMessage(for: .entryValidationFailed))
        )
      }

      let entryText: String?
      if !trimmed.isEmpty {
        entryText = trimmed
      } else if !page.markers.isEmpty {
        entryText = page.markers.map { "[\($0.number)]" }.joined(separator: " ")
      } else {
        entryText = nil
      }

      validated.append(
        ValidatedSummaryPage(
          draft: page.draft,
          initialEntryText: entryText,
          markers: page.markers
        )
      )
    }

    return .success(validated)
  }

  // Decision S2-2 & S2-7: Persist each photo and its optional initial entry atomically.
  static func persistPages(
    _ request: PersistSummaryRequest,
    in database: any DatabaseWriter
  ) throws {
    let mediaStore = MediaMutationStore(database: database)
    let queueForCloud = request.mode == .cloud

    for page in request.pages {
      let mediaItem = makeMediaItem(
        from: page.draft,
        apartmentId: request.apartmentId,
        currentUser: request.currentUser,
        queueForCloud: queueForCloud
      )
      let initialEntry = makeInitialEntry(
        for: page,
        mediaId: mediaItem.id,
        currentUser: request.currentUser,
        idGenerator: request.idGenerator,
        now: request.now
      )
      let mediaOutboxId = queueForCloud ? request.idGenerator.generate() : ""
      let entryOutboxId =
        (queueForCloud && initialEntry != nil)
        ? request.idGenerator.generate()
        : ""
      try mediaStore.saveLocalMedia(
        mediaItem,
        location: page.draft.location,
        initialEntry: initialEntry,
        queueForCloud: queueForCloud,
        mediaOutboxId: mediaOutboxId,
        entryOutboxId: entryOutboxId,
        now: request.now
      )
    }
  }

  private static func makeInitialEntry(
    for page: ValidatedSummaryPage,
    mediaId: String,
    currentUser: AuthorSummary,
    idGenerator: any IDGenerator,
    now: Date
  ) -> EntryItem? {
    guard let entryText = page.initialEntryText else {
      return nil
    }
    let entryId = idGenerator.generate()
    let markers = page.markers.map {
      $0.toMarkerPoint(entryId: entryId, mediaId: mediaId)
    }
    return EntryItem(
      id: entryId,
      mediaId: mediaId,
      authorId: currentUser.userId,
      author: currentUser,
      text: entryText,
      markers: markers,
      createdAt: now
    )
  }

  private static func makeMediaItem(
    from draft: CapturedPhotoDraft,
    apartmentId: String,
    currentUser: AuthorSummary,
    queueForCloud: Bool
  ) -> MediaItem {
    MediaItem(
      id: draft.id,
      apartmentId: apartmentId,
      authorId: currentUser.userId,
      author: currentUser,
      kind: .photo,
      source: draft.source,
      sha256: draft.sha256,
      capturedAt: draft.capturedAt,
      capturedTz: draft.capturedTz,
      capturedAtFromImport: draft.capturedAtFromImport,
      width: draft.width,
      height: draft.height,
      bytes: draft.bytes,
      syncState: queueForCloud ? .queued : .localOnly,
      localFilePath: draft.localFilePath
    )
  }
}
