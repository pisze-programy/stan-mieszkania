import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import MediaStorage
import SyncEngine

@Reducer
public struct MediaDetailFeature: Sendable {
  @ObservableState
  public struct State: Equatable, Sendable {
    public let apartmentId: String
    public let mediaId: String
    public var media: MediaItem?
    public var mediaAuthorName: String
    public var mediaAuthorColorHex: String
    public var entries: [MediaDetailEntryItem]
    public var currentUser: AuthorSummary?
    public var selectedMarkerNumber: Int?
    public var scrollTargetEntryId: String?
    public var uploadProgress: Double?
    public var isUploadingToCloud: Bool
    public var isPhotoCached: Bool
    public var composer: EntryComposerState?
    public var isMetadataSheetPresented: Bool
    public var mediaDeleteConfirmation: MediaDeleteConfirmationMode?
    public var entryDeleteConfirmation: EntryDeleteConfirmation?
    public var errorMessage: String?
    public var quotaNoticeMessage: String?
    public var now: Date?

    public init(
      apartmentId: String,
      mediaId: String,
      media: MediaItem? = nil,
      mediaAuthorName: String = "",
      mediaAuthorColorHex: String = DomainConstants.defaultAuthorColor,
      entries: [MediaDetailEntryItem] = [],
      currentUser: AuthorSummary? = nil,
      selectedMarkerNumber: Int? = nil,
      scrollTargetEntryId: String? = nil,
      uploadProgress: Double? = nil,
      isUploadingToCloud: Bool = false,
      isPhotoCached: Bool = false,
      composer: EntryComposerState? = nil,
      isMetadataSheetPresented: Bool = false,
      mediaDeleteConfirmation: MediaDeleteConfirmationMode? = nil,
      entryDeleteConfirmation: EntryDeleteConfirmation? = nil,
      errorMessage: String? = nil,
      quotaNoticeMessage: String? = nil,
      now: Date? = nil
    ) {
      self.apartmentId = apartmentId
      self.mediaId = mediaId
      self.media = media
      self.mediaAuthorName = mediaAuthorName
      self.mediaAuthorColorHex = mediaAuthorColorHex
      self.entries = entries
      self.currentUser = currentUser
      self.selectedMarkerNumber = selectedMarkerNumber
      self.scrollTargetEntryId = scrollTargetEntryId
      self.uploadProgress = uploadProgress
      self.isUploadingToCloud = isUploadingToCloud
      self.isPhotoCached = isPhotoCached
      self.composer = composer
      self.isMetadataSheetPresented = isMetadataSheetPresented
      self.mediaDeleteConfirmation = mediaDeleteConfirmation
      self.entryDeleteConfirmation = entryDeleteConfirmation
      self.errorMessage = errorMessage
      self.quotaNoticeMessage = quotaNoticeMessage
      self.now = now
    }
  }

  public enum Action: Equatable, Sendable {
    case task
    case snapshotLoaded(MediaDetailSnapshot)
    case photoCacheReady
    case syncEventReceived(SyncEvent)
    case uploadToCloudTapped
    case uploadToCloudFinished(MediaDetailSnapshot)
    case uploadToCloudFailed(String)
    case dismissError
    case dismissQuotaNotice
    case markerTapped(Int)
    case markerSelectionCleared
    case scrollTargetHandled
    case addEntryTapped
    case editLocalEntryTapped(String)
    case composerDismissed
    case composerTextChanged(String)
    case composerToggleMarkerMode
    case composerMarkerAdded(x: Double, y: Double)
    case composerMarkerDeleted(Int)
    case composerSubmitted
    case composerSucceeded(MediaDetailSnapshot)
    case composerFailed(String)
    case entryDeleteTapped(String)
    case entryDeleteConfirmationDismissed
    case entryDeleteConfirmed
    case entryDeleteSucceeded(MediaDetailSnapshot, shouldSyncOutbox: Bool)
    case entryDeleteFailed(String)
    case metadataTapped
    case metadataDismissed
    case mediaDeleteTapped
    case mediaDeleteConfirmationDismissed
    case mediaDeleteConfirmed
    case mediaHardDeleteSucceeded
    case mediaSoftDeleteSucceeded(MediaDetailSnapshot)
    case mediaDeleteFailed(String)
    case delegate(Delegate)

    @CasePathable
    public enum Delegate: Equatable, Sendable {
      case didDeleteLocalMedia(mediaId: String)
    }
  }

  enum CancelID: Hashable, Sendable {
    case syncEvents
  }

  @Dependency(\.defaultDatabase) var database
  @Dependency(\.syncEngine) var syncEngine
  @Dependency(\.mediaStorage) var mediaStorage
  @Dependency(\.haptics) var haptics
  @Dependency(\.date.now) var now
  @Dependency(\.idGenerator) var idGenerator

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task, .snapshotLoaded, .photoCacheReady, .syncEventReceived, .uploadToCloudTapped,
        .uploadToCloudFinished, .uploadToCloudFailed:
        return handleSyncAction(&state, action: action)
      case .dismissError:
        state.errorMessage = nil
        return .none
      case .dismissQuotaNotice:
        state.quotaNoticeMessage = nil
        return .none
      case .markerTapped(let number):
        state.selectedMarkerNumber = number
        state.scrollTargetEntryId = state.entryId(owningMarker: number)
        return .none
      case .markerSelectionCleared:
        state.selectedMarkerNumber = nil
        state.scrollTargetEntryId = nil
        return .none
      case .scrollTargetHandled:
        state.scrollTargetEntryId = nil
        return .none
      case .addEntryTapped, .editLocalEntryTapped, .composerDismissed, .composerTextChanged,
        .composerToggleMarkerMode, .composerMarkerAdded, .composerMarkerDeleted,
        .composerSubmitted, .composerSucceeded, .composerFailed:
        return handleComposerAction(&state, action: action)
      case .entryDeleteTapped, .entryDeleteConfirmationDismissed, .entryDeleteConfirmed,
        .entryDeleteSucceeded, .entryDeleteFailed, .metadataTapped, .metadataDismissed,
        .mediaDeleteTapped, .mediaDeleteConfirmationDismissed, .mediaDeleteConfirmed,
        .mediaHardDeleteSucceeded, .mediaSoftDeleteSucceeded, .mediaDeleteFailed:
        return handleMutationAction(&state, action: action)
      case .delegate:
        return .none
      }
    }
  }
}
