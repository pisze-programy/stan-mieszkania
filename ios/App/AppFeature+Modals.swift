import ApartmentTimelineFeature
import CaptureFeature
import ComposableArchitecture
import Domain
import Foundation
import MediaSummaryFeature

extension AppFeature {
  func handleCaptureDelegate(
    _ state: inout State,
    delegate: CaptureFeature.Action.Delegate
  ) -> Effect<Action> {
    let apartmentId = state.capture?.apartmentId
    state.capture = nil
    if let apartmentId {
      setTimelineCaptureInProgress(&state, apartmentId: apartmentId, inProgress: false)
    }

    switch delegate {
    case .didFinishCapture(let drafts, let origin):
      guard let apartmentId, !drafts.isEmpty, state.modal == nil else {
        return .none
      }
      let author = resolveCurrentAuthorSummary(for: state)
      state.modal = .mediaSummary(
        MediaSummaryFeature.State(
          apartmentId: apartmentId,
          drafts: drafts,
          origin: origin,
          currentUser: author
        )
      )
      return .none
    case .didCancel:
      return .none
    }
  }

  func handleModalDismiss(_ state: inout State) -> Effect<Action> {
    switch state.modal {
    case .mediaSummary(let summaryState):
      // Invariant 8: Interactive sheet swipe-dismiss cleans up unsaved draft JPEGs on disk.
      let draftIds = summaryState.pages.map(\.draft.id)
      let storage = mediaStorage
      return .run { _ in
        for mediaId in draftIds {
          try? await storage.deleteLocalFile(mediaId)
        }
      }
    case .sharing:
      return reloadLocalData(in: state)
    case nil:
      return .none
    }
  }

  func handleModalDelegate(
    _ state: inout State,
    action: AppModalDestination.Action
  ) -> Effect<Action> {
    switch action {
    case .sharing(.delegate(.didDismiss)):
      state.modal = nil
      return reloadLocalData(in: state)
    case .mediaSummary(.delegate(let delegate)):
      return handleSummaryDelegate(&state, delegate: delegate)
    default:
      return .none
    }
  }

  private func handleSummaryDelegate(
    _ state: inout State,
    delegate: MediaSummaryFeature.Action.Delegate
  ) -> Effect<Action> {
    guard case .mediaSummary(let summaryState) = state.modal else {
      state.modal = nil
      return .none
    }
    switch delegate {
    case .didSave(_, let captureAnother):
      state.modal = nil
      if captureAnother {
        return .merge(
          reloadLocalData(in: state),
          startCapture(&state, apartmentId: summaryState.apartmentId, source: .camera)
        )
      }
      return reloadLocalData(in: state)
    case .didRequestRetake(let origin):
      state.modal = nil
      return startCapture(&state, apartmentId: summaryState.apartmentId, source: origin)
    case .didCancel:
      state.modal = nil
      return .none
    }
  }

  func startCapture(
    _ state: inout State,
    apartmentId: String,
    source: CaptureSourceKind
  ) -> Effect<Action> {
    guard state.capture == nil, state.modal == nil else {
      return .none
    }
    state.capture = CaptureFeature.State(apartmentId: apartmentId, source: source)
    setTimelineCaptureInProgress(&state, apartmentId: apartmentId, inProgress: true)
    return .send(.capture(.start))
  }

  func setTimelineCaptureInProgress(
    _ state: inout State,
    apartmentId: String,
    inProgress: Bool
  ) {
    for id in state.path.ids {
      if case .apartmentTimeline(var timelineState) = state.path[id: id] {
        if timelineState.apartmentId == apartmentId {
          timelineState.isCaptureInProgress = inProgress
          state.path[id: id] = .apartmentTimeline(timelineState)
        }
      }
    }
  }

  private func resolveCurrentAuthorSummary(for state: State) -> AuthorSummary {
    let profile = state.currentUser ?? state.apartmentsList.currentUser
    var activeRole: MemberRole = .owner
    for element in state.path.reversed() {
      if case .apartmentTimeline(let timelineState) = element {
        activeRole = timelineState.callerRole
        break
      }
    }
    return AuthorSummary(
      userId: profile?.id ?? "",
      displayName: profile?.displayName ?? DomainConstants.fallbackUserDisplayPrefix,
      shortTag: profile?.shortTag ?? "",
      color: profile?.color ?? DomainConstants.defaultAuthorColor,
      role: activeRole
    )
  }
}
