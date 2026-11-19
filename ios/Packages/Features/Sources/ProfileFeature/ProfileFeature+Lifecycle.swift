import AuthClient
import ComposableArchitecture
import DesignSystem
import Foundation

extension ProfileFeature {
  private static let localDevTokenPrefix: String = "dev:"

  func handleSignOutAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .signOutTapped:
      guard !state.isBusy else {
        return .none
      }
      state.isSignOutConfirmationPresented = true
      return .none
    case .signOutConfirmationDismissed:
      state.isSignOutConfirmationPresented = false
      return .none
    case .signOutConfirmed:
      return executeSignOut(&state)
    case .signOutCompleted:
      state.isSigningOut = false
      state.user = nil
      return .merge(
        .run { _ in
          await haptics.actionSucceeded()
        },
        .send(.delegate(.didSignOut))
      )
    case .signOutFailed(let message):
      state.isSigningOut = false
      state.errorMessage = message
      return .run { _ in
        await haptics.error()
      }
    default:
      return .none
    }
  }

  func handleDeleteAccountAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .deleteAccountTapped:
      guard !state.isBusy else {
        return .none
      }
      state.isDeleteImpactSheetPresented = true
      return .none
    case .deleteImpactSheetDismissed:
      state.isDeleteImpactSheetPresented = false
      return .none
    case .deleteImpactContinueTapped:
      state.isDeleteImpactSheetPresented = false
      state.isDeleteFinalConfirmationPresented = true
      return .none
    case .deleteFinalConfirmationDismissed:
      state.isDeleteFinalConfirmationPresented = false
      return .none
    case .deleteAccountConfirmed:
      return executeDeleteAccount(&state)
    case .deleteAccountCancelled:
      state.isDeletingAccount = false
      return .none
    case .deleteAccountSucceeded:
      state.isDeletingAccount = false
      state.user = nil
      return .merge(
        .run { _ in
          await haptics.actionSucceeded()
        },
        .send(.delegate(.didDeleteAccount))
      )
    case .deleteAccountFailed(let message):
      state.isDeletingAccount = false
      state.errorMessage = message
      return .run { _ in
        await haptics.error()
      }
    default:
      return .none
    }
  }

  private func executeSignOut(_ state: inout State) -> Effect<Action> {
    guard !state.isBusy else {
      return .none
    }
    state.isSignOutConfirmationPresented = false
    state.isSigningOut = true
    state.errorMessage = nil
    return .run { send in
      do {
        try await wipeLocalStorageAndSession()
        await send(.signOutCompleted)
      } catch {
        await send(.signOutFailed(mapError(error)))
      }
    }
  }

  // Decision Q5 & Q12: Revoke Apple token and delete server account before wiping local data.
  private func executeDeleteAccount(_ state: inout State) -> Effect<Action> {
    guard !state.isBusy else {
      return .none
    }
    state.isDeleteFinalConfirmationPresented = false
    state.isDeletingAccount = true
    state.errorMessage = nil
    return .run { send in
      do {
        let appleAuthCode = try await resolveAppleAuthorizationCode()
        try await apiClient.deleteMyAccount(appleAuthCode)
        try await wipeLocalStorageAndSession()
        await send(.deleteAccountSucceeded)
      } catch let authError as AuthClientError where authError == .cancelled {
        await send(.deleteAccountCancelled)
      } catch is CancellationError {
        await send(.deleteAccountCancelled)
      } catch {
        await send(.deleteAccountFailed(mapError(error)))
      }
    }
  }

  private func resolveAppleAuthorizationCode() async throws -> String? {
    let session = try? await authClient.loadStoredSession()
    if session?.bearerToken.hasPrefix(Self.localDevTokenPrefix) == true {
      return nil
    }
    do {
      return try await authClient.requestFreshAppleAuthorizationCode()
    } catch let authError as AuthClientError where authError == .appleSignInUnavailable {
      return nil
    }
  }

  private func wipeLocalStorageAndSession() async throws {
    let mediaIds = try ProfileStore.wipeAllLocalData(in: database)
    for mediaId in mediaIds {
      try? mediaStorage.deleteLocalFile(mediaId)
    }
    try await authClient.clearSession()
  }
}
