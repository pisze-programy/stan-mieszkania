import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import MediaStorage
import SyncEngine

@Reducer
public struct MediaSummaryFeature: Sendable {
  @ObservableState
  public struct State: Equatable, Sendable {
    public let apartmentId: String
    public let origin: CaptureSourceKind
    public let currentUser: AuthorSummary
    public var pages: [MediaSummaryPageState]
    public var selectedIndex: Int
    public var isSaveSheetPresented: Bool
    public var pendingSavedMode: MediaSummarySaveMode?
    public var savingMode: MediaSummarySaveMode?
    public var saveErrorMessage: String?
    public var errorMessage: String?
    public var now: Date?

    public var isSaving: Bool {
      savingMode != nil
    }

    public var currentPage: MediaSummaryPageState? {
      guard pages.indices.contains(selectedIndex) else {
        return nil
      }
      return pages[selectedIndex]
    }

    public var isMultiPhoto: Bool {
      pages.count > 1
    }

    public init(
      apartmentId: String,
      drafts: [CapturedPhotoDraft],
      origin: CaptureSourceKind,
      currentUser: AuthorSummary,
      selectedIndex: Int = 0,
      isSaveSheetPresented: Bool = false,
      pendingSavedMode: MediaSummarySaveMode? = nil,
      savingMode: MediaSummarySaveMode? = nil,
      saveErrorMessage: String? = nil,
      errorMessage: String? = nil,
      now: Date? = nil
    ) {
      self.apartmentId = apartmentId
      self.origin = origin
      self.currentUser = currentUser
      self.pages = drafts.map { MediaSummaryPageState(draft: $0) }
      let clampedIndex = drafts.isEmpty ? 0 : min(max(0, selectedIndex), drafts.count - 1)
      self.selectedIndex = clampedIndex
      self.isSaveSheetPresented = isSaveSheetPresented
      self.pendingSavedMode = pendingSavedMode
      self.savingMode = savingMode
      self.saveErrorMessage = saveErrorMessage
      self.errorMessage = errorMessage
      self.now = now
    }
  }

  public enum Action: Equatable, Sendable {
    case task
    case pageSelected(Int)
    case markerAddedAt(x: Double, y: Double)
    case markerSelected(Int)
    case markerSelectionCleared
    case markerRemoveRequested(Int)
    case descriptionChanged(String)
    case cancelTapped
    case saveButtonTapped
    case saveSheetDismissed
    case saveSheetDidDismiss
    case saveTapped(mode: MediaSummarySaveMode)
    case saveSucceeded(mode: MediaSummarySaveMode)
    case saveFailed(String)
    case dismissError
    case delegate(Delegate)

    @CasePathable
    public enum Delegate: Equatable, Sendable {
      case didSave(mode: MediaSummarySaveMode)
      case didCancel
    }
  }

  @Dependency(\.defaultDatabase) var database
  @Dependency(\.mediaStorage) var mediaStorage
  @Dependency(\.syncEngine) var syncEngine
  @Dependency(\.haptics) var haptics
  @Dependency(\.date.now) var now
  @Dependency(\.timeZone) var timeZone
  @Dependency(\.idGenerator) var idGenerator

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        state.now = now
        return .none
      case .pageSelected(let index):
        guard state.pages.indices.contains(index) else {
          return .none
        }
        state.selectedIndex = index
        return .none
      case .markerAddedAt(let x, let y):
        return addMarker(&state, x: x, y: y)
      case .markerSelected(let number):
        return selectMarker(&state, number: number)
      case .markerSelectionCleared:
        return clearMarkerSelection(&state)
      case .markerRemoveRequested(let number):
        return removeMarker(&state, number: number)
      case .descriptionChanged(let value):
        return updateDescription(&state, value: value)
      case .cancelTapped:
        return discardAndEmit(&state, delegate: .didCancel)
      case .saveButtonTapped:
        return openSaveSheet(&state)
      case .saveSheetDismissed:
        guard !state.isSaving else {
          return .none
        }
        state.isSaveSheetPresented = false
        state.saveErrorMessage = nil
        return .none
      case .saveSheetDidDismiss:
        return handleSaveSheetDidDismiss(&state)
      case .saveTapped(let mode):
        return startSave(&state, mode: mode)
      case .saveSucceeded(let mode):
        state.savingMode = nil
        state.pendingSavedMode = mode
        state.isSaveSheetPresented = false
        return .none
      case .saveFailed(let message):
        state.savingMode = nil
        state.saveErrorMessage = message
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
}
