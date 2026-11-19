import APIClient
import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import SyncEngine

@Reducer
public struct ApartmentsListFeature: Sendable {
  @ObservableState
  public struct State: Equatable, Sendable {
    public var currentUser: UserProfile?
    public var items: [ApartmentListItem]
    public var isSyncing: Bool
    public var errorMessage: String?
    public var createSheet: CreateApartmentSheetState?
    public var joinSheet: JoinApartmentSheetState?

    public init(
      currentUser: UserProfile? = nil,
      items: [ApartmentListItem] = [],
      isSyncing: Bool = false,
      errorMessage: String? = nil,
      createSheet: CreateApartmentSheetState? = nil,
      joinSheet: JoinApartmentSheetState? = nil
    ) {
      self.currentUser = currentUser
      self.items = items
      self.isSyncing = isSyncing
      self.errorMessage = errorMessage
      self.createSheet = createSheet
      self.joinSheet = joinSheet
    }
  }

  public struct CreateApartmentSheetState: Equatable, Sendable {
    public var name: String = ""
    public var street: String = ""
    public var city: String = ""
    public var isSaving: Bool = false
    public var errorMessage: String?

    public init(
      name: String = "",
      street: String = "",
      city: String = "",
      isSaving: Bool = false,
      errorMessage: String? = nil
    ) {
      self.name = name
      self.street = street
      self.city = city
      self.isSaving = isSaving
      self.errorMessage = errorMessage
    }
  }

  public struct JoinApartmentSheetState: Equatable, Sendable {
    public var inviteCode: String = ""
    public var isJoining: Bool = false
    public var errorMessage: String?

    public init(
      inviteCode: String = "",
      isJoining: Bool = false,
      errorMessage: String? = nil
    ) {
      self.inviteCode = inviteCode
      self.isJoining = isJoining
      self.errorMessage = errorMessage
    }
  }

  public enum Action: Equatable, Sendable {
    case task
    case pulledToRefresh
    case reloadLocalState
    case localDataLoaded(user: UserProfile?, items: [ApartmentListItem])
    case syncCompleted(user: UserProfile?, items: [ApartmentListItem])
    case syncFailed(String)
    case syncEventReceived(SyncEvent)
    case dismissError
    case apartmentTapped(String)
    case profileTapped
    case createMenuTapped
    case createSheetDismissed
    case createNameChanged(String)
    case createStreetChanged(String)
    case createCityChanged(String)
    case createSubmitted
    case createSucceeded(user: UserProfile?, items: [ApartmentListItem])
    case createFailed(String)
    case joinMenuTapped
    case joinSheetDismissed
    case joinCodeChanged(String)
    case joinSubmitted
    case joinSucceeded(apartmentId: String, user: UserProfile?, items: [ApartmentListItem])
    case joinFailed(String)
    case delegate(Delegate)

    @CasePathable
    public enum Delegate: Equatable, Sendable {
      case didSelectApartment(String)
      case didTapProfile
    }
  }

  enum CancelID {
    case syncEvents
  }

  @Dependency(\.defaultDatabase) var database
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.syncEngine) var syncEngine
  @Dependency(\.haptics) var haptics
  @Dependency(\.date.now) var now
  @Dependency(\.idGenerator) var idGenerator

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        return .merge(
          startSync(&state),
          listenToSyncEvents()
        )
      case .pulledToRefresh:
        return startSync(&state)
      case .reloadLocalState:
        return reloadLocalSnapshot()
      case .localDataLoaded(let user, let items):
        state.currentUser = user
        state.items = items
        return .none
      case .syncCompleted(let user, let items):
        state.isSyncing = false
        state.currentUser = user
        state.items = items
        return .none
      case .syncFailed(let message):
        state.isSyncing = false
        state.errorMessage = message
        return .none
      case .syncEventReceived(let event):
        return handleSyncEvent(event)
      case .dismissError:
        state.errorMessage = nil
        return .none
      case .apartmentTapped(let apartmentId):
        return .send(.delegate(.didSelectApartment(apartmentId)))
      case .profileTapped:
        return .send(.delegate(.didTapProfile))
      case .createMenuTapped, .createSheetDismissed, .createNameChanged,
        .createStreetChanged, .createCityChanged, .createSubmitted,
        .createSucceeded, .createFailed:
        return handleCreateAction(&state, action: action)
      case .joinMenuTapped, .joinSheetDismissed, .joinCodeChanged,
        .joinSubmitted, .joinSucceeded, .joinFailed:
        return handleJoinAction(&state, action: action)
      case .delegate:
        return .none
      }
    }
  }
}
