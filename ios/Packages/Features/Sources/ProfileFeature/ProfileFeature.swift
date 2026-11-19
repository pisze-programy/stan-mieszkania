import APIClient
import AuthClient
import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import MediaStorage

@Reducer
public struct ProfileFeature: Sendable {
  @ObservableState
  public struct State: Equatable, Sendable {
    public var user: UserProfile?
    public var displayNameInput: String
    public var selectedTheme: AppThemePreference
    public var isLoading: Bool
    public var isSavingName: Bool
    public var showNameSavedFeedback: Bool
    public var isSigningOut: Bool
    public var isDeletingAccount: Bool
    public var isSignOutConfirmationPresented: Bool
    public var isDeleteImpactSheetPresented: Bool
    public var isDeleteFinalConfirmationPresented: Bool
    public var errorMessage: String?

    public var isBusy: Bool {
      isSavingName || isSigningOut || isDeletingAccount
    }

    public init(
      user: UserProfile? = nil,
      displayNameInput: String? = nil,
      selectedTheme: AppThemePreference = .system,
      isLoading: Bool = false,
      isSavingName: Bool = false,
      showNameSavedFeedback: Bool = false,
      isSigningOut: Bool = false,
      isDeletingAccount: Bool = false,
      isSignOutConfirmationPresented: Bool = false,
      isDeleteImpactSheetPresented: Bool = false,
      isDeleteFinalConfirmationPresented: Bool = false,
      errorMessage: String? = nil
    ) {
      self.user = user
      self.displayNameInput = displayNameInput ?? user?.displayName ?? ""
      self.selectedTheme = selectedTheme
      self.isLoading = isLoading
      self.isSavingName = isSavingName
      self.showNameSavedFeedback = showNameSavedFeedback
      self.isSigningOut = isSigningOut
      self.isDeletingAccount = isDeletingAccount
      self.isSignOutConfirmationPresented = isSignOutConfirmationPresented
      self.isDeleteImpactSheetPresented = isDeleteImpactSheetPresented
      self.isDeleteFinalConfirmationPresented = isDeleteFinalConfirmationPresented
      self.errorMessage = errorMessage
    }
  }

  public enum Action: Equatable, Sendable {
    case task
    case localProfileLoaded(UserProfile?, theme: AppThemePreference)
    case remoteProfileLoaded(UserProfile)
    case profileLoadFailed(String)
    case displayNameChanged(String)
    case saveDisplayNameTapped
    case saveDisplayNameSucceeded(UserProfile)
    case saveDisplayNameFailed(String)
    case themeChanged(AppThemePreference)
    case signOutTapped
    case signOutConfirmationDismissed
    case signOutConfirmed
    case signOutCompleted
    case signOutFailed(String)
    case deleteAccountTapped
    case deleteImpactSheetDismissed
    case deleteImpactContinueTapped
    case deleteFinalConfirmationDismissed
    case deleteAccountConfirmed
    case deleteAccountCancelled
    case deleteAccountSucceeded
    case deleteAccountFailed(String)
    case dismissError
    case delegate(Delegate)

    @CasePathable
    public enum Delegate: Equatable, Sendable {
      case didChangeTheme(AppThemePreference)
      case didSignOut
      case didDeleteAccount
    }
  }

  @Dependency(\.defaultDatabase) var database
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.authClient) var authClient
  @Dependency(\.mediaStorage) var mediaStorage
  @Dependency(\.themePreference) var themePreference
  @Dependency(\.haptics) var haptics

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task, .localProfileLoaded, .remoteProfileLoaded, .profileLoadFailed:
        return handleLoadAction(&state, action: action)
      case .displayNameChanged, .saveDisplayNameTapped, .saveDisplayNameSucceeded,
        .saveDisplayNameFailed, .themeChanged:
        return handleSettingsAction(&state, action: action)
      case .signOutTapped, .signOutConfirmationDismissed, .signOutConfirmed,
        .signOutCompleted, .signOutFailed:
        return handleSignOutAction(&state, action: action)
      case .deleteAccountTapped, .deleteImpactSheetDismissed, .deleteImpactContinueTapped,
        .deleteFinalConfirmationDismissed, .deleteAccountConfirmed,
        .deleteAccountCancelled, .deleteAccountSucceeded, .deleteAccountFailed:
        return handleDeleteAccountAction(&state, action: action)
      case .dismissError:
        state.errorMessage = nil
        return .none
      case .delegate:
        return .none
      }
    }
  }
}
