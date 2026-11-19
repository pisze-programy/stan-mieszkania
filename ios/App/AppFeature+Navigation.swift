import ApartmentTimelineFeature
import ApartmentsListFeature
import CaptureFeature
import ComposableArchitecture
import Domain
import Foundation
import MediaDetailFeature
import OnboardingFeature
import ProfileFeature
import SharingFeature

extension AppFeature {
  func handleOnboardingDelegate(
    _ state: inout State,
    delegate: OnboardingFeature.Action.Delegate
  ) -> Effect<Action> {
    switch delegate {
    case .didAuthenticate(let profile):
      state.isAuthenticated = true
      state.currentUser = profile
      state.path = StackState()
      state.capture = nil
      state.modal = nil
      state.apartmentsList = ApartmentsListFeature.State(currentUser: profile)
      return .none
    }
  }

  func handleApartmentsListDelegate(
    _ state: inout State,
    delegate: ApartmentsListFeature.Action.Delegate
  ) -> Effect<Action> {
    switch delegate {
    case .didSelectApartment(let apartmentId):
      state.path.append(
        .apartmentTimeline(ApartmentTimelineFeature.State(apartmentId: apartmentId)))
      return .none
    case .didTapProfile:
      state.path.append(
        .profile(
          ProfileFeature.State(
            user: state.currentUser ?? state.apartmentsList.currentUser,
            selectedTheme: state.themePreference
          )
        )
      )
      return .none
    }
  }

  func handlePathPop(_ state: inout State, id: StackElementID) -> Effect<Action> {
    guard
      let activeCapture = state.capture,
      case .apartmentTimeline(let timeline) = state.path[id: id],
      timeline.apartmentId == activeCapture.apartmentId
    else {
      return .none
    }
    state.capture = nil
    return .none
  }

  func handlePathDelegate(
    _ state: inout State,
    id: StackElementID,
    action: AppPath.Action
  ) -> Effect<Action> {
    switch action {
    case .apartmentTimeline(.delegate(let delegate)):
      return handleTimelineDelegate(&state, id: id, delegate: delegate)
    case .mediaDetail(.delegate(.didDeleteLocalMedia)):
      state.path.pop(from: id)
      return reloadLocalData(in: state)
    case .profile(.delegate(let delegate)):
      return handleProfileDelegate(&state, delegate: delegate)
    default:
      return .none
    }
  }

  private func handleTimelineDelegate(
    _ state: inout State,
    id: StackElementID,
    delegate: ApartmentTimelineFeature.Action.Delegate
  ) -> Effect<Action> {
    switch delegate {
    case .didSelectMedia(let mediaId):
      guard case .apartmentTimeline(let timelineState) = state.path[id: id] else {
        return .none
      }
      state.path.append(
        .mediaDetail(
          MediaDetailFeature.State(
            apartmentId: timelineState.apartmentId,
            mediaId: mediaId
          )
        )
      )
      return .none
    case .didTapShare(let apartmentId):
      state.modal = .sharing(SharingFeature.State(apartmentId: apartmentId))
      return .none
    case .didSelectCaptureSource(let apartmentId, let source):
      return startCapture(&state, apartmentId: apartmentId, source: source)
    case .didLeaveOrDeleteApartment:
      if case .apartmentTimeline(let timeline) = state.path[id: id] {
        if state.capture?.apartmentId == timeline.apartmentId {
          state.capture = nil
        }
      }
      state.path.pop(from: id)
      return .send(.apartmentsList(.pulledToRefresh))
    }
  }

  private func handleProfileDelegate(
    _ state: inout State,
    delegate: ProfileFeature.Action.Delegate
  ) -> Effect<Action> {
    switch delegate {
    case .didChangeTheme(let preference):
      state.themePreference = preference
      return .none
    case .didUpdateProfile(let profile):
      state.currentUser = profile
      state.apartmentsList.currentUser = profile
      return .none
    case .didSignOut, .didDeleteAccount:
      state.isAuthenticated = false
      state.currentUser = nil
      state.path = StackState()
      state.capture = nil
      state.modal = nil
      state.apartmentsList = ApartmentsListFeature.State()
      state.onboarding = OnboardingFeature.State()
      return .none
    }
  }

  func reloadLocalData(in state: State) -> Effect<Action> {
    var effects: [Effect<Action>] = [.send(.apartmentsList(.reloadLocalState))]
    for (id, element) in zip(state.path.ids, state.path).reversed() {
      if case .apartmentTimeline = element {
        effects.append(
          .send(.path(.element(id: id, action: .apartmentTimeline(.reloadLocalState))))
        )
        break
      }
    }
    return .merge(effects)
  }
}
