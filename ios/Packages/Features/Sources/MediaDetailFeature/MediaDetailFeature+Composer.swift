import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation

extension MediaDetailFeature {
  func handleComposerAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .addEntryTapped, .editLocalEntryTapped, .composerDismissed, .composerTextChanged,
      .composerToggleMarkerMode, .composerMarkerAdded, .composerMarkerDeleted:
      return handleComposerDraftAction(&state, action: action)
    case .composerSubmitted:
      return submitComposer(&state)
    case .composerSucceeded(let snapshot):
      state.composer = nil
      applySnapshot(snapshot, to: &state)
      let shouldProcessOutbox = snapshot.media?.syncState != .localOnly
      return .merge(
        .run { _ in await haptics.actionSucceeded() },
        shouldProcessOutbox ? .run { _ in _ = await syncEngine.processOutbox() } : .none
      )
    case .composerFailed(let message):
      state.composer?.isSubmitting = false
      state.composer?.errorMessage = message
      return .run { _ in await haptics.error() }
    default:
      return .none
    }
  }

  private func handleComposerDraftAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .addEntryTapped:
      guard state.canComposeEntry else { return .none }
      state.composer = EntryComposerState()
      return .none
    case .editLocalEntryTapped(let entryId):
      return openLocalEntryEditor(&state, entryId: entryId)
    case .composerDismissed:
      state.composer = nil
      return .none
    case .composerTextChanged(let value):
      state.composer?.text = value
      state.composer?.errorMessage = nil
      return .none
    case .composerToggleMarkerMode:
      state.composer?.isMarkerPlacementMode.toggle()
      return .none
    case .composerMarkerAdded(let x, let y):
      return addComposerMarker(&state, x: x, y: y)
    case .composerMarkerDeleted(let number):
      return deleteComposerMarker(&state, number: number)
    default:
      return .none
    }
  }

  private func openLocalEntryEditor(_ state: inout State, entryId: String) -> Effect<Action> {
    guard
      let item = state.entries.first(where: { $0.id == entryId }),
      state.canEditOrHardDeleteEntry(item)
    else {
      return .none
    }
    let draftMarkers = item.entry.markers.map {
      DetailDraftMarker(id: $0.id, number: $0.number, x: $0.x, y: $0.y)
    }
    state.composer = EntryComposerState(
      editingEntryId: item.id,
      text: item.entry.text,
      markers: draftMarkers
    )
    return .none
  }

  private func addComposerMarker(_ state: inout State, x: Double, y: Double) -> Effect<Action> {
    guard let composer = state.composer, composer.isMarkerPlacementMode else {
      return .none
    }
    let clampedX = MarkerOverlayItem.clampedNormalizedCoordinate(x)
    let clampedY = MarkerOverlayItem.clampedNormalizedCoordinate(y)
    // Decision S2-2: Draft markers start after the highest existing marker number on this photo.
    let nextNumber = MarkerTextPolicy.nextDraftMarkerNumber(
      existingMaxNumber: state.maxExistingMarkerNumber,
      currentDraftNumbers: composer.markers.map(\.number)
    )
    let marker = DetailDraftMarker(
      id: idGenerator.generate(),
      number: nextNumber,
      x: clampedX,
      y: clampedY
    )
    state.composer?.markers.append(marker)
    state.composer?.text = MarkerTextPolicy.appendMarkerToken(to: composer.text, number: nextNumber)
    state.selectedMarkerNumber = nextNumber
    return .run { _ in await haptics.markerDropped() }
  }

  private func deleteComposerMarker(_ state: inout State, number: Int) -> Effect<Action> {
    guard let composer = state.composer else {
      return .none
    }
    state.composer?.markers.removeAll { $0.number == number }
    state.composer?.text = MarkerTextPolicy.removeMarkerToken(from: composer.text, number: number)
    if state.selectedMarkerNumber == number {
      state.selectedMarkerNumber = nil
    }
    return .none
  }

  private func submitComposer(_ state: inout State) -> Effect<Action> {
    guard
      let composer = state.composer,
      !composer.isSubmitting,
      let media = state.media,
      let currentUser = state.currentUser
    else {
      return .none
    }
    switch MediaDetailStore.validateEntryText(composer.text, markers: composer.markers) {
    case .failure(let failure):
      state.composer?.errorMessage = failure.message
      return .run { _ in await haptics.warning() }
    case .success(let validatedText):
      state.composer?.isSubmitting = true
      state.composer?.errorMessage = nil
      return persistComposerEntry(
        composer: composer,
        validatedText: validatedText,
        media: media,
        currentUser: currentUser
      )
    }
  }

  private func persistComposerEntry(
    composer: EntryComposerState,
    validatedText: String,
    media: MediaItem,
    currentUser: AuthorSummary
  ) -> Effect<Action> {
    let timestamp = now
    let generator = idGenerator
    let mediaId = media.id
    let queueForCloud = media.syncState != .localOnly

    return .run { send in
      do {
        let entryStore = EntryMutationStore(database: database)
        if let editingEntryId = composer.editingEntryId {
          let markers = composer.markers.map {
            $0.toMarkerPoint(entryId: editingEntryId, mediaId: mediaId)
          }
          try entryStore.updateLocalEntry(
            entryId: editingEntryId,
            actorId: currentUser.userId,
            text: validatedText,
            markers: markers,
            now: timestamp
          )
        } else {
          let entryId = generator.generate()
          let markers = composer.markers.map {
            $0.toMarkerPoint(entryId: entryId, mediaId: mediaId)
          }
          let entry = EntryItem(
            id: entryId,
            mediaId: mediaId,
            authorId: currentUser.userId,
            author: currentUser,
            text: validatedText,
            markers: markers,
            createdAt: timestamp
          )
          let outboxId = queueForCloud ? generator.generate() : ""
          try entryStore.createEntry(
            entry,
            queueForCloud: queueForCloud,
            outboxId: outboxId,
            now: timestamp
          )
        }
        let updated = try MediaDetailStore.fetchSnapshot(mediaId: mediaId, from: database)
        await send(.composerSucceeded(updated))
      } catch {
        await send(.composerFailed(L10n.errorMessage(for: error)))
      }
    }
  }
}
