import ApartmentTimelineFeature
import ApartmentsListFeature
import AppConfigClient
import AuthClient
import CaptureFeature
import ComposableArchitecture
import Database
import Domain
import Foundation
import MediaDetailFeature
import MediaStorage
import MediaSummaryFeature
import OnboardingFeature
import ProfileFeature
import SharingFeature
import SyncEngine

@Reducer
public enum AppPath {
  case apartmentTimeline(ApartmentTimelineFeature)
  case mediaDetail(MediaDetailFeature)
  case profile(ProfileFeature)
}

extension AppPath.State: Equatable, Sendable {}
extension AppPath.Action: Equatable, Sendable {}

@Reducer
public enum AppModalDestination {
  case sharing(SharingFeature)
  case mediaSummary(MediaSummaryFeature)
}

extension AppModalDestination.State: Equatable, Sendable {}
extension AppModalDestination.Action: Equatable, Sendable {}

@Reducer
public struct AppFeature: Sendable {
  @ObservableState
  public struct State: Equatable, Sendable {
    public var isBootstrapping: Bool
    public var isAuthenticated: Bool
    public var themePreference: AppThemePreference
    public var isForceUpdateRequired: Bool
    public var forceUpdateMinVersion: String?
    public var currentUser: UserProfile?
    public var onboarding: OnboardingFeature.State
    public var apartmentsList: ApartmentsListFeature.State
    public var path: StackState<AppPath.State>
    public var capture: CaptureFeature.State?
    @Presents public var modal: AppModalDestination.State?

    public init(
      isBootstrapping: Bool = true,
      isAuthenticated: Bool = false,
      themePreference: AppThemePreference = .system,
      isForceUpdateRequired: Bool = false,
      forceUpdateMinVersion: String? = nil,
      currentUser: UserProfile? = nil,
      onboarding: OnboardingFeature.State = OnboardingFeature.State(),
      apartmentsList: ApartmentsListFeature.State = ApartmentsListFeature.State(),
      path: StackState<AppPath.State> = StackState(),
      capture: CaptureFeature.State? = nil,
      modal: AppModalDestination.State? = nil
    ) {
      self.isBootstrapping = isBootstrapping
      self.isAuthenticated = isAuthenticated
      self.themePreference = themePreference
      self.isForceUpdateRequired = isForceUpdateRequired
      self.forceUpdateMinVersion = forceUpdateMinVersion
      self.currentUser = currentUser
      self.onboarding = onboarding
      self.apartmentsList = apartmentsList
      self.path = path
      self.capture = capture
      self.modal = modal
    }
  }

  public enum Action: Equatable, Sendable {
    case task
    case bootstrapResolved(
      isAuthenticated: Bool,
      currentUser: UserProfile?,
      theme: AppThemePreference
    )
    case appConfigResolved(ResolvedAppConfig)
    case syncEventReceived(SyncEvent)
    case onboarding(OnboardingFeature.Action)
    case apartmentsList(ApartmentsListFeature.Action)
    case path(StackActionOf<AppPath>)
    case capture(CaptureFeature.Action)
    case modal(PresentationAction<AppModalDestination.Action>)
  }

  enum CancelID: Hashable, Sendable {
    case syncEvents
  }

  @Dependency(\.defaultDatabase) var database
  @Dependency(\.mediaStorage) var mediaStorage
  @Dependency(\.authClient) var authClient
  @Dependency(\.appConfigClient) var appConfigClient
  @Dependency(\.syncEngine) var syncEngine
  @Dependency(\.themePreference) var themePreference
  @Dependency(\.appEnvironment) var appEnvironment
  @Dependency(\.date.now) var now

  public init() {}

  public var body: some ReducerOf<Self> {
    Scope(state: \.onboarding, action: \.onboarding) { OnboardingFeature() }
    Scope(state: \.apartmentsList, action: \.apartmentsList) { ApartmentsListFeature() }
    Reduce { state, action in
      switch action {
      case .task, .bootstrapResolved, .appConfigResolved, .syncEventReceived:
        return handleAppLifecycle(&state, action: action)
      case .onboarding(.delegate(let delegate)):
        return handleOnboardingDelegate(&state, delegate: delegate)
      case .apartmentsList(.delegate(let delegate)):
        return handleApartmentsListDelegate(&state, delegate: delegate)
      case .path(.element(id: let id, action: let pathAction)):
        return handlePathDelegate(&state, id: id, action: pathAction)
      case .path(.popFrom(id: let id)):
        return handlePathPop(&state, id: id)
      case .capture(.delegate(let delegate)):
        return handleCaptureDelegate(&state, delegate: delegate)
      case .modal(.presented(let modalAction)):
        return handleModalDelegate(&state, action: modalAction)
      case .modal(.dismiss):
        return handleModalDismiss(&state)
      case .onboarding, .apartmentsList, .path, .capture:
        return .none
      }
    }
    .forEach(\.path, action: \.path)
    .ifLet(\.capture, action: \.capture) {
      CaptureFeature()
    }
    .ifLet(\.$modal, action: \.modal)
  }

  private func handleAppLifecycle(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .task:
      return startBootstrap(&state)
    case .bootstrapResolved(let isAuthenticated, let currentUser, let theme):
      state.isBootstrapping = false
      state.isAuthenticated = isAuthenticated
      state.currentUser = currentUser
      state.themePreference = theme
      return .none
    case .appConfigResolved(let resolved):
      // Architecture A19: Trigger force-update gate without deleting local SQLiteData or outbox.
      if case .forceUpdateRequired(let minVersion) = resolved.updateStatus {
        state.isForceUpdateRequired = true
        state.forceUpdateMinVersion = minVersion
      }
      return .none
    case .syncEventReceived(let event):
      if case .forceUpdateRequired(let minVersion) = event {
        state.isForceUpdateRequired = true
        state.forceUpdateMinVersion = minVersion
      }
      return .none
    default:
      return .none
    }
  }

  private func startBootstrap(_ state: inout State) -> Effect<Action> {
    let bootstrapEffect: Effect<Action> = .run { send in
      let theme = themePreference.load()
      let session = try? await authClient.loadStoredSession()
      let user = try? ApartmentMutationStore(database: database).fetchCurrentUser()
      await send(
        .bootstrapResolved(
          isAuthenticated: session != nil,
          currentUser: user,
          theme: theme
        )
      )
      let resolvedConfig = await appConfigClient.refresh()
      await send(.appConfigResolved(resolvedConfig))
    }

    let syncEventsEffect: Effect<Action> = .run { send in
      let stream = await syncEngine.events()
      for await event in stream {
        await send(.syncEventReceived(event))
      }
    }
    .cancellable(id: CancelID.syncEvents, cancelInFlight: true)

    return .merge(bootstrapEffect, syncEventsEffect)
  }
}
