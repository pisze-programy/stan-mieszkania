import APIClient
import ComposableArchitecture
import DesignSystem
import Domain
import Foundation

extension ProfileFeature {
  func handleLoadAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .task:
      return loadProfile(&state)
    case .localProfileLoaded(let user, let theme):
      state.user = user
      if state.displayNameInput.isEmpty, let user {
        state.displayNameInput = user.displayName
      }
      state.selectedTheme = theme
      return .none
    case .remoteProfileLoaded(let profile):
      state.isLoading = false
      state.user = profile
      state.displayNameInput = profile.displayName
      return .send(.delegate(.didUpdateProfile(profile)))
    case .profileLoadFailed(let message):
      state.isLoading = false
      state.errorMessage = message
      return .none
    default:
      return .none
    }
  }

  func handleSettingsAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .displayNameChanged(let value):
      state.displayNameInput = value
      state.showNameSavedFeedback = false
      state.errorMessage = nil
      return .none
    case .saveDisplayNameTapped:
      return saveDisplayName(&state)
    case .saveDisplayNameSucceeded(let updated):
      state.isSavingName = false
      state.user = updated
      state.displayNameInput = updated.displayName
      state.showNameSavedFeedback = true
      return .merge(
        .run { _ in
          await haptics.actionSucceeded()
        },
        .send(.delegate(.didUpdateProfile(updated)))
      )
    case .saveDisplayNameFailed(let message):
      state.isSavingName = false
      state.errorMessage = message
      return .run { _ in
        await haptics.error()
      }
    case .themeChanged(let preference):
      state.selectedTheme = preference
      return .merge(
        .run { _ in
          themePreference.save(preference)
        },
        .send(.delegate(.didChangeTheme(preference)))
      )
    default:
      return .none
    }
  }

  private func loadProfile(_ state: inout State) -> Effect<Action> {
    guard !state.isLoading else {
      return .none
    }
    state.isLoading = true
    state.errorMessage = nil
    return .run { send in
      let localUser = try? ProfileStore.fetchCurrentUser(from: database)
      let savedTheme = themePreference.load()
      await send(.localProfileLoaded(localUser, theme: savedTheme))

      do {
        let remoteProfile = try await apiClient.getMyProfile()
        try ProfileStore.saveUpdatedUser(remoteProfile, in: database)
        await send(.remoteProfileLoaded(remoteProfile))
      } catch {
        await send(.profileLoadFailed(mapError(error)))
      }
    }
  }

  private func saveDisplayName(_ state: inout State) -> Effect<Action> {
    guard !state.isBusy else {
      return .none
    }
    let trimmed = state.displayNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard
      trimmed.count >= ContractConstants.displayNameMinLength,
      trimmed.count <= ContractConstants.displayNameMaxLength
    else {
      state.errorMessage = L10n.errorMessage(for: .displayNameInvalid)
      return .run { _ in
        await haptics.warning()
      }
    }

    state.isSavingName = true
    state.showNameSavedFeedback = false
    state.errorMessage = nil
    return .run { send in
      do {
        let updated = try await apiClient.updateMyProfile(trimmed)
        try ProfileStore.saveUpdatedUser(updated, in: database)
        await send(.saveDisplayNameSucceeded(updated))
      } catch {
        await send(.saveDisplayNameFailed(mapError(error)))
      }
    }
  }

  func mapError(_ error: any Error) -> String {
    if let problem = error as? APIProblemError {
      return L10n.errorMessage(for: problem.code)
    }
    return L10n.errorMessage(for: .unknown("PROFILE_ERROR"))
  }
}
