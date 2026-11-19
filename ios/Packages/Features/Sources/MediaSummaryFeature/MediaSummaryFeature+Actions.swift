import ComposableArchitecture
import DesignSystem
import Domain
import Foundation

extension MediaSummaryFeature {
  func addMarker(_ state: inout State, x: Double, y: Double) -> Effect<Action> {
    guard state.isMarkerPlacementMode, state.pages.indices.contains(state.selectedIndex) else {
      return .none
    }
    let clampedX = MarkerOverlayItem.clampedNormalizedCoordinate(x)
    let clampedY = MarkerOverlayItem.clampedNormalizedCoordinate(y)
    let currentNumbers = state.pages[state.selectedIndex].markers.map(\.number)
    let nextNumber = MarkerTextPolicy.nextDraftMarkerNumber(
      existingMaxNumber: 0,
      currentDraftNumbers: currentNumbers
    )
    let marker = SummaryDraftMarker(
      id: idGenerator.generate(),
      number: nextNumber,
      x: clampedX,
      y: clampedY
    )
    state.pages[state.selectedIndex].markers.append(marker)
    state.pages[state.selectedIndex].description = MarkerTextPolicy.appendMarkerToken(
      to: state.pages[state.selectedIndex].description,
      number: nextNumber
    )
    state.pages[state.selectedIndex].selectedMarkerNumber = nextNumber
    return .run { _ in
      await haptics.markerDropped()
    }
  }

  func selectMarker(_ state: inout State, number: Int) -> Effect<Action> {
    guard state.pages.indices.contains(state.selectedIndex) else {
      return .none
    }
    state.pages[state.selectedIndex].selectedMarkerNumber = number
    return .none
  }

  func clearMarkerSelection(_ state: inout State) -> Effect<Action> {
    guard state.pages.indices.contains(state.selectedIndex) else {
      return .none
    }
    state.pages[state.selectedIndex].selectedMarkerNumber = nil
    return .none
  }

  func deleteMarker(_ state: inout State, number: Int) -> Effect<Action> {
    guard state.pages.indices.contains(state.selectedIndex) else {
      return .none
    }
    state.pages[state.selectedIndex].markers.removeAll { $0.number == number }
    state.pages[state.selectedIndex].description = MarkerTextPolicy.removeMarkerToken(
      from: state.pages[state.selectedIndex].description,
      number: number
    )
    if state.pages[state.selectedIndex].selectedMarkerNumber == number {
      state.pages[state.selectedIndex].selectedMarkerNumber = nil
    }
    return .none
  }

  func updateDescription(_ state: inout State, value: String) -> Effect<Action> {
    guard state.pages.indices.contains(state.selectedIndex) else {
      return .none
    }
    state.pages[state.selectedIndex].description = value
    state.errorMessage = nil
    return .none
  }

  // Invariant 8: Clean up unsaved local JPEG files on retake or cancel to avoid orphaned disk files.
  func discardAndEmit(_ state: inout State, delegate: Action.Delegate) -> Effect<Action> {
    guard !state.isSaving else {
      return .none
    }
    let mediaIds = state.pages.map(\.draft.id)
    return .run { send in
      for mediaId in mediaIds {
        try? mediaStorage.deleteLocalFile(mediaId)
      }
      await send(.delegate(delegate))
    }
  }

  func startSave(
    _ state: inout State,
    mode: MediaSummarySaveMode,
    captureAnother: Bool
  ) -> Effect<Action> {
    guard !state.isSaving else {
      return .none
    }
    switch MediaSummaryStore.validatePages(state.pages) {
    case .failure(let failure):
      state.errorMessage = failure.message
      return .run { _ in
        await haptics.warning()
      }
    case .success(let validatedPages):
      state.isSaving = true
      state.errorMessage = nil
      let request = PersistSummaryRequest(
        pages: validatedPages,
        apartmentId: state.apartmentId,
        currentUser: state.currentUser,
        mode: mode,
        idGenerator: idGenerator,
        now: now
      )
      return .run { send in
        do {
          try MediaSummaryStore.persistPages(request, in: database)
          await send(.saveSucceeded(mode: mode, captureAnother: captureAnother))
        } catch {
          await send(
            .saveFailed(L10n.errorMessage(for: .unknown(MediaSummaryConstants.unknownErrorCode)))
          )
        }
      }
    }
  }

  // Decision S2-7: Return immediately on save and process cloud outbox asynchronously in background.
  func finishSave(
    _ state: inout State,
    mode: MediaSummarySaveMode,
    captureAnother: Bool
  ) -> Effect<Action> {
    state.isSaving = false
    return .merge(
      .run { _ in
        await haptics.actionSucceeded()
      },
      .send(.delegate(.didSave(mode: mode, captureAnother: captureAnother))),
      mode == .cloud
        ? .run { _ in
          _ = await syncEngine.processOutbox()
        }
        : .none
    )
  }
}
