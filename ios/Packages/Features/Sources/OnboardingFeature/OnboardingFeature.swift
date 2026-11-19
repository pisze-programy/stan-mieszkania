import APIClient
import AuthClient
import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation

@Reducer
public struct OnboardingFeature: Sendable {
  @ObservableState
  public struct State: Equatable, Sendable {
    public var isSigningIn: Bool
    public var errorMessage: String?
    public var isLocalDevLoginEnabled: Bool
    public var isLocalDevSheetPresented: Bool
    public var backgroundVideoURL: URL?

    public init(
      isSigningIn: Bool = false,
      errorMessage: String? = nil,
      isLocalDevLoginEnabled: Bool = false,
      isLocalDevSheetPresented: Bool = false,
      backgroundVideoURL: URL? = nil
    ) {
      self.isSigningIn = isSigningIn
      self.errorMessage = errorMessage
      self.isLocalDevLoginEnabled = isLocalDevLoginEnabled
      self.isLocalDevSheetPresented = isLocalDevSheetPresented
      self.backgroundVideoURL = backgroundVideoURL
    }
  }

  public enum Action: Equatable, Sendable {
    case signInWithAppleTapped
    case localDevSignInSheetPresented(Bool)
    case localDevSignInSubmitted(uid: String, displayName: String?)
    case authSucceeded(UserProfile)
    case authCancelled
    case authFailed(String)
    case dismissError
    case delegate(Delegate)

    @CasePathable
    public enum Delegate: Equatable, Sendable {
      case didAuthenticate(UserProfile)
    }
  }

  @Dependency(\.authClient) private var authClient
  @Dependency(\.apiClient) private var apiClient
  @Dependency(\.defaultDatabase) private var database
  @Dependency(\.haptics) private var haptics

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .signInWithAppleTapped:
        guard !state.isSigningIn else {
          return .none
        }
        state.isSigningIn = true
        state.errorMessage = nil
        return .run { send in
          await performAuthentication(send: send) {
            _ = try await authClient.signInWithApple()
          }
        }

      case .localDevSignInSheetPresented(let presented):
        state.isLocalDevSheetPresented = presented
        return .none

      case .localDevSignInSubmitted(let uid, let displayName):
        guard !state.isSigningIn else {
          return .none
        }
        state.isSigningIn = true
        state.isLocalDevSheetPresented = false
        state.errorMessage = nil
        return .run { send in
          await performAuthentication(send: send) {
            _ = try await authClient.signInLocalDev(uid, displayName)
          }
        }

      case .authSucceeded(let profile):
        state.isSigningIn = false
        state.errorMessage = nil
        return .merge(
          .run { _ in
            await haptics.actionSucceeded()
          },
          .send(.delegate(.didAuthenticate(profile)))
        )

      case .authCancelled:
        state.isSigningIn = false
        return .none

      case .authFailed(let message):
        state.isSigningIn = false
        state.errorMessage = message
        return .run { _ in
          await haptics.error()
        }

      case .dismissError:
        state.errorMessage = nil
        return .none

      case .delegate:
        return .none
      }
    }
  }

  private func performAuthentication(
    send: Send<Action>,
    authenticate: () async throws -> Void
  ) async {
    do {
      try await authenticate()
      let profile = try await apiClient.getMyProfile()
      let store = ApartmentMutationStore(database: database)
      try store.saveLocalUser(profile, isCurrentUser: true)
      await send(.authSucceeded(profile))
    } catch let authError as AuthClientError where authError == .cancelled {
      await send(.authCancelled)
    } catch is CancellationError {
      await send(.authCancelled)
    } catch {
      try? await authClient.clearSession()
      await send(.authFailed(mapErrorMessage(error)))
    }
  }

  private func mapErrorMessage(_ error: any Error) -> String {
    if error is AuthClientError {
      return L10n.errorMessage(for: .authTokenInvalid)
    }
    return L10n.errorMessage(for: error)
  }
}
