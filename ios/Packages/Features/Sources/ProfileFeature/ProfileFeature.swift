import APIClient
import AuthClient
import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import MediaStorage

public enum DeleteAccountStep: Equatable, Sendable {
  case impact
  case finalConfirm
}

@Reducer
public struct ProfileFeature: Sendable {
  @ObservableState
  public struct State: Equatable, Sendable {
    public var user: UserProfile?
    public var displayNameInput: String
    public var selectedTheme: AppThemePreference
    public var localOnlyMediaCount: Int
    public var isLoading: Bool
    public var isSavingName: Bool
    public var showNameSavedFeedback: Bool
    public var isSigningOut: Bool
    public var isDeletingAccount: Bool
    public var isSignOutConfirmationPresented: Bool
    public var deleteAccountStep: DeleteAccountStep?
    public var errorMessage: String?

    public var isBusy: Bool {
      isSavingName || isSigningOut || isDeletingAccount
    }

    public var isNameDirty: Bool {
      let trimmed = displayNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
      guard
        trimmed.count >= ContractConstants.displayNameMinLength,
        trimmed.count <= ContractConstants.displayNameMaxLength
      else {
        return false
      }
      return trimmed != user?.displayName
    }

    public var signOutConfirmationContent: ConfirmationSheetContent {
      if localOnlyMediaCount > 0 {
        return ConfirmationSheetContent(
          systemImage: "exclamationmark.triangle.fill",
          title: L10n.string("profile.sign.out.confirm.title"),
          message: L10n.signOutLocalOnlyMessage(localOnlyMediaCount),
          confirmTitle: L10n.string("profile.sign.out"),
          tone: .destructive
        )
      }
      return ConfirmationSheetContent(
        systemImage: "rectangle.portrait.and.arrow.right",
        title: L10n.string("profile.sign.out.confirm.title"),
        message: L10n.string("profile.sign.out.message.safe"),
        confirmTitle: L10n.string("profile.sign.out"),
        tone: .neutral
      )
    }

    public init(
      user: UserProfile? = nil,
      displayNameInput: String? = nil,
      selectedTheme: AppThemePreference = .system,
      localOnlyMediaCount: Int = 0,
      isLoading: Bool = false,
      isSavingName: Bool = false,
      showNameSavedFeedback: Bool = false,
      isSigningOut: Bool = false,
      isDeletingAccount: Bool = false,
      isSignOutConfirmationPresented: Bool = false,
      deleteAccountStep: DeleteAccountStep? = nil,
      errorMessage: String? = nil
    ) {
      self.user = user
      self.displayNameInput = displayNameInput ?? user?.displayName ?? ""
      self.selectedTheme = selectedTheme
      self.localOnlyMediaCount = localOnlyMediaCount
      self.isLoading = isLoading
      self.isSavingName = isSavingName
      self.showNameSavedFeedback = showNameSavedFeedback
      self.isSigningOut = isSigningOut
      self.isDeletingAccount = isDeletingAccount
      self.isSignOutConfirmationPresented = isSignOutConfirmationPresented
      self.deleteAccountStep = deleteAccountStep
      self.errorMessage = errorMessage
    }
  }

  public enum Action: Equatable, Sendable {
    case task
    case localProfileLoaded(UserProfile?, theme: AppThemePreference, localOnlyMediaCount: Int)
    case remoteProfileLoaded(UserProfile)
    case profileLoadFailed(String)
    case displayNameChanged(String)
    case saveDisplayNameTapped
    case saveDisplayNameSucceeded(UserProfile)
    case saveDisplayNameFailed(String)
    case dismissNameSavedFeedback
    case themeChanged(AppThemePreference)
    case signOutTapped
    case signOutConfirmationDismissed
    case signOutConfirmed
    case signOutCompleted
    case signOutFailed(String)
    case deleteAccountTapped
    case deleteImpactContinueTapped
    case deleteAccountSheetDismissed
    case deleteAccountConfirmed
    case deleteAccountCancelled
    case deleteAccountSucceeded
    case deleteAccountFailed(String)
    case dismissError
    case delegate(Delegate)

    @CasePathable
    public enum Delegate: Equatable, Sendable {
      case didChangeTheme(AppThemePreference)
      case didUpdateProfile(UserProfile)
      case didSignOut
      case didDeleteAccount
    }
  }

  enum CancelID: Hashable, Sendable {
    case savedFeedback
  }

  static let savedFeedbackDurationMilliseconds: Int = 1_500

  @Dependency(\.defaultDatabase) var database
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.authClient) var authClient
  @Dependency(\.mediaStorage) var mediaStorage
  @Dependency(\.themePreference) var themePreference
  @Dependency(\.haptics) var haptics
  @Dependency(\.continuousClock) var clock

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task, .localProfileLoaded, .remoteProfileLoaded, .profileLoadFailed:
        return handleLoadAction(&state, action: action)
      case .displayNameChanged, .saveDisplayNameTapped, .saveDisplayNameSucceeded,
        .saveDisplayNameFailed, .dismissNameSavedFeedback, .themeChanged:
        return handleSettingsAction(&state, action: action)
      case .signOutTapped, .signOutConfirmationDismissed, .signOutConfirmed,
        .signOutCompleted, .signOutFailed:
        return handleSignOutAction(&state, action: action)
      case .deleteAccountTapped, .deleteImpactContinueTapped, .deleteAccountSheetDismissed,
        .deleteAccountConfirmed, .deleteAccountCancelled, .deleteAccountSucceeded,
        .deleteAccountFailed:
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
