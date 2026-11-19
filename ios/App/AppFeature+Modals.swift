import ApartmentTimelineFeature
import CaptureFeature
import ComposableArchitecture
import Domain
import Foundation
import MediaSummaryFeature

extension AppFeature {
  func handleModalDelegate(
    _ state: inout State,
    action: AppModalDestination.Action
  ) -> Effect<Action> {
    switch action {
    case .sharing(.delegate(.didDismiss)):
      state.modal = nil
      return .none
    case .capture(.delegate(let delegate)):
      return handleCaptureDelegate(&state, delegate: delegate)
    case .mediaSummary(.delegate(let delegate)):
      return handleSummaryDelegate(&state, delegate: delegate)
    default:
      return .none
    }
  }

  private func handleCaptureDelegate(
    _ state: inout State,
    delegate: CaptureFeature.Action.Delegate
  ) -> Effect<Action> {
    switch delegate {
    case .didFinishCapture(let drafts, let origin):
      guard !drafts.isEmpty, case .capture(let captureState) = state.modal else {
        state.modal = nil
        return .none
      }
      let author = resolveCurrentAuthorSummary(for: state)
      state.modal = .mediaSummary(
        MediaSummaryFeature.State(
          apartmentId: captureState.apartmentId,
          drafts: drafts,
          origin: origin,
          currentUser: author
        )
      )
      return .none
    case .didCancel:
      state.modal = nil
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
      if captureAnother {
        state.modal = .capture(
          CaptureFeature.State(apartmentId: summaryState.apartmentId, source: .camera)
        )
        return .none
      }
      state.modal = nil
      return refreshTopTimelineIfPresent(in: state)
    case .didRequestRetake(let origin):
      state.modal = .capture(
        CaptureFeature.State(apartmentId: summaryState.apartmentId, source: origin)
      )
      return .none
    case .didCancel:
      state.modal = nil
      return .none
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
