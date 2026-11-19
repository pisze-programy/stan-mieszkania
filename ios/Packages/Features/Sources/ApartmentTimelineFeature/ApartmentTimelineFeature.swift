import APIClient
import AppConfigClient
import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import MediaStorage
import SyncEngine

@Reducer
public struct ApartmentTimelineFeature: Sendable {
  @ObservableState
  public struct State: Equatable, Sendable {
    public let apartmentId: String
    public var apartment: Apartment?
    public var sections: [TimelineDaySection]
    public var localUnsyncedCount: Int
    public var cloudMediaCount: Int
    public var quotaLimit: Int
    public var uploadProgressByMediaId: [String: Double]
    public var isSyncing: Bool
    public var isSyncingAllLocal: Bool
    public var errorMessage: String?
    public var quotaNoticeMessage: String?
    public var isCaptureInProgress: Bool
    public var editSheet: EditApartmentSheetState?
    public var historySheet: ApartmentHistorySheetState?
    public var leaveConfirmationMode: LeaveOrDeleteMode?
    public var isLeavingOrDeleting: Bool
    public var now: Date?

    public var callerRole: MemberRole { apartment?.role ?? .contributor }
    public var isOwner: Bool { callerRole == .owner }
    public var shouldHighlightShare: Bool {
      isOwner && (apartment?.shouldSuggestInviteCodeReset ?? false)
    }
    public var navigationTitle: String {
      apartment?.name ?? L10n.string("apartments.list.title")
    }

    public init(
      apartmentId: String,
      apartment: Apartment? = nil,
      sections: [TimelineDaySection] = [],
      localUnsyncedCount: Int = 0,
      cloudMediaCount: Int = 0,
      quotaLimit: Int = ContractConstants.defaultCloudMediaQuotaPerApartment,
      uploadProgressByMediaId: [String: Double] = [:],
      isSyncing: Bool = false,
      isSyncingAllLocal: Bool = false,
      errorMessage: String? = nil,
      quotaNoticeMessage: String? = nil,
      isCaptureInProgress: Bool = false,
      editSheet: EditApartmentSheetState? = nil,
      historySheet: ApartmentHistorySheetState? = nil,
      leaveConfirmationMode: LeaveOrDeleteMode? = nil,
      isLeavingOrDeleting: Bool = false,
      now: Date? = nil
    ) {
      self.apartmentId = apartmentId
      self.apartment = apartment
      self.sections = sections
      self.localUnsyncedCount = localUnsyncedCount
      self.cloudMediaCount = cloudMediaCount
      self.quotaLimit = quotaLimit
      self.uploadProgressByMediaId = uploadProgressByMediaId
      self.isSyncing = isSyncing
      self.isSyncingAllLocal = isSyncingAllLocal
      self.errorMessage = errorMessage
      self.quotaNoticeMessage = quotaNoticeMessage
      self.isCaptureInProgress = isCaptureInProgress
      self.editSheet = editSheet
      self.historySheet = historySheet
      self.leaveConfirmationMode = leaveConfirmationMode
      self.isLeavingOrDeleting = isLeavingOrDeleting
      self.now = now
    }
  }

  public enum Action: Equatable, Sendable {
    case task
    case pulledToRefresh
    case reloadLocalState
    case localSnapshotLoaded(ApartmentTimelineSnapshot)
    case syncCompleted(ApartmentTimelineSnapshot)
    case syncFailed(String)
    case syncEventReceived(SyncEvent)
    case syncAllLocalTapped
    case syncAllLocalCompleted(ApartmentTimelineSnapshot)
    case syncAllLocalFailed(String)
    case dismissError
    case dismissQuotaNotice
    case mediaTapped(String)
    case shareTapped
    case captureSourceSelected(CaptureSource)
    case editMenuTapped
    case editSheetDismissed
    case editNameChanged(String)
    case editStreetChanged(String)
    case editCityChanged(String)
    case editSubmitted
    case editSucceeded(ApartmentTimelineSnapshot)
    case editFailed(String)
    case historyMenuTapped
    case historySheetDismissed
    case historyLoaded(changes: [ApartmentChange], authorNames: [String: String])
    case historyFailed(String)
    case leaveOrDeleteMenuTapped
    case leaveConfirmationDismissed
    case leaveOrDeleteConfirmed
    case leaveOrDeleteSucceeded
    case leaveOrDeleteFailed(String)
    case delegate(Delegate)

    @CasePathable
    public enum Delegate: Equatable, Sendable {
      case didSelectMedia(mediaId: String)
      case didTapShare(apartmentId: String)
      case didSelectCaptureSource(apartmentId: String, source: CaptureSource)
      case didLeaveOrDeleteApartment
    }
  }

  enum CancelID: Hashable, Sendable {
    case syncEvents
  }

  @Dependency(\.defaultDatabase) var database
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.syncEngine) var syncEngine
  @Dependency(\.mediaStorage) var mediaStorage
  @Dependency(\.appConfigClient) var appConfigClient
  @Dependency(\.haptics) var haptics
  @Dependency(\.date.now) var now
  @Dependency(\.calendar) var calendar
  @Dependency(\.timeZone) var timeZone
  @Dependency(\.idGenerator) var idGenerator

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task, .pulledToRefresh, .reloadLocalState, .localSnapshotLoaded, .syncCompleted,
        .syncFailed, .syncEventReceived, .syncAllLocalTapped, .syncAllLocalCompleted,
        .syncAllLocalFailed:
        return handleSyncAction(&state, action: action)
      case .dismissError:
        state.errorMessage = nil
        return .none
      case .dismissQuotaNotice:
        state.quotaNoticeMessage = nil
        return .none
      case .mediaTapped(let mediaId):
        return .send(.delegate(.didSelectMedia(mediaId: mediaId)))
      case .shareTapped:
        guard state.isOwner else {
          return .none
        }
        return .send(.delegate(.didTapShare(apartmentId: state.apartmentId)))
      case .captureSourceSelected(let source):
        guard !state.isCaptureInProgress else {
          return .none
        }
        return .send(
          .delegate(.didSelectCaptureSource(apartmentId: state.apartmentId, source: source))
        )
      case .editMenuTapped, .editSheetDismissed, .editNameChanged, .editStreetChanged,
        .editCityChanged, .editSubmitted, .editSucceeded, .editFailed, .historyMenuTapped,
        .historySheetDismissed, .historyLoaded, .historyFailed, .leaveOrDeleteMenuTapped,
        .leaveConfirmationDismissed, .leaveOrDeleteConfirmed, .leaveOrDeleteSucceeded,
        .leaveOrDeleteFailed:
        return handleManagementAction(&state, action: action)
      case .delegate:
        return .none
      }
    }
  }
}
