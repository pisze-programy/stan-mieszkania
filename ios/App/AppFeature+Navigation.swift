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
      return refreshTopTimelineIfPresent(in: state)
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
      state.modal = .capture(CaptureFeature.State(apartmentId: apartmentId, source: source))
      return .none
    case .didLeaveOrDeleteApartment:
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
    case .didSignOut, .didDeleteAccount:
      state.isAuthenticated = false
      state.currentUser = nil
      state.path = StackState()
      state.modal = nil
      state.apartmentsList = ApartmentsListFeature.State()
      state.onboarding = OnboardingFeature.State(
        isLocalDevLoginEnabled: appEnvironment.isLocalDevLoginEnabled
      )
      return .none
    }
  }

  func refreshTopTimelineIfPresent(in state: State) -> Effect<Action> {
    for (id, element) in zip(state.path.ids, state.path).reversed() {
      if case .apartmentTimeline = element {
        return .send(.path(.element(id: id, action: .apartmentTimeline(.pulledToRefresh))))
      }
    }
    return .none
  }
}
