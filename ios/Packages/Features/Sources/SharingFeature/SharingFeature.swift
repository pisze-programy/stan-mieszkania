import APIClient
import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import SyncEngine

@Reducer
public struct SharingFeature: Sendable {
  @ObservableState
  public struct State: Equatable, Sendable {
    public let apartmentId: String
    public var apartment: Apartment?
    public var members: [ApartmentMember]
    public var isLoading: Bool
    public var isResettingCode: Bool
    public var revokingUserId: String?
    public var showCopiedFeedback: Bool
    public var isResetConfirmationPresented: Bool
    public var pendingRevokeMember: ApartmentMember?
    public var errorMessage: String?

    public var inviteCode: String? { apartment?.inviteCode }
    public var shouldSuggestInviteCodeReset: Bool {
      apartment?.shouldSuggestInviteCodeReset ?? false
    }
    public var isOwner: Bool { apartment?.role == .owner }
    public var activeMembers: [ApartmentMember] { members.filter(\.isActive) }
    public var departedMembers: [ApartmentMember] { members.filter { !$0.isActive } }

    public var shareMessageText: String? {
      guard let apartment, let code = apartment.inviteCode else {
        return nil
      }
      return L10n.format("sharing.sms.message", apartment.name, code)
    }

    public init(
      apartmentId: String,
      apartment: Apartment? = nil,
      members: [ApartmentMember] = [],
      isLoading: Bool = false,
      isResettingCode: Bool = false,
      revokingUserId: String? = nil,
      showCopiedFeedback: Bool = false,
      isResetConfirmationPresented: Bool = false,
      pendingRevokeMember: ApartmentMember? = nil,
      errorMessage: String? = nil
    ) {
      self.apartmentId = apartmentId
      self.apartment = apartment
      self.members = members
      self.isLoading = isLoading
      self.isResettingCode = isResettingCode
      self.revokingUserId = revokingUserId
      self.showCopiedFeedback = showCopiedFeedback
      self.isResetConfirmationPresented = isResetConfirmationPresented
      self.pendingRevokeMember = pendingRevokeMember
      self.errorMessage = errorMessage
    }
  }

  public enum Action: Equatable, Sendable {
    case task
    case refreshed
    case localDataLoaded(apartment: Apartment?, members: [ApartmentMember])
    case remoteDataLoaded(apartment: Apartment, members: [ApartmentMember])
    case loadFailed(String)
    case copyCodeTapped
    case dismissCopiedFeedback
    case resetCodeTapped
    case resetConfirmationDismissed
    case resetCodeConfirmed
    case resetCodeSucceeded(Apartment)
    case resetCodeFailed(String)
    case revokeMemberTapped(ApartmentMember)
    case revokeConfirmationDismissed
    case revokeMemberConfirmed
    case revokeMemberSucceeded(apartment: Apartment?, members: [ApartmentMember])
    case revokeMemberFailed(String)
    case dismissError
    case delegate(Delegate)

    @CasePathable
    public enum Delegate: Equatable, Sendable {
      case didDismiss
    }
  }

  @Dependency(\.defaultDatabase) var database
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.syncEngine) var syncEngine
  @Dependency(\.pasteboard) var pasteboard
  @Dependency(\.haptics) var haptics
  @Dependency(\.date.now) var now

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task, .refreshed:
        return loadSharingData(&state)
      case .localDataLoaded(let apartment, let members):
        state.apartment = apartment
        state.members = members
        return .none
      case .remoteDataLoaded(let apartment, let members):
        state.isLoading = false
        state.apartment = apartment
        state.members = members
        return .none
      case .loadFailed(let message):
        state.isLoading = false
        state.errorMessage = message
        return .none
      case .copyCodeTapped:
        return handleCopyCode(&state)
      case .dismissCopiedFeedback:
        state.showCopiedFeedback = false
        return .none
      case .resetCodeTapped, .resetConfirmationDismissed, .resetCodeConfirmed,
        .resetCodeSucceeded, .resetCodeFailed:
        return handleResetAction(&state, action: action)
      case .revokeMemberTapped, .revokeConfirmationDismissed, .revokeMemberConfirmed,
        .revokeMemberSucceeded, .revokeMemberFailed:
        return handleRevokeAction(&state, action: action)
      case .dismissError:
        state.errorMessage = nil
        return .none
      case .delegate:
        return .none
      }
    }
  }
}
