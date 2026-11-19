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
    public var isMarkerPlacementMode: Bool
    public var isSaving: Bool
    public var errorMessage: String?
    public var now: Date?

    public var currentPage: MediaSummaryPageState? {
      guard pages.indices.contains(selectedIndex) else {
        return nil
      }
      return pages[selectedIndex]
    }

    public var isMultiPhoto: Bool {
      pages.count > 1
    }

    public var showsCaptureAnotherAction: Bool {
      origin == .camera
    }

    public init(
      apartmentId: String,
      drafts: [CapturedPhotoDraft],
      origin: CaptureSourceKind,
      currentUser: AuthorSummary,
      selectedIndex: Int = 0,
      isMarkerPlacementMode: Bool = false,
      isSaving: Bool = false,
      errorMessage: String? = nil,
      now: Date? = nil
    ) {
      self.apartmentId = apartmentId
      self.origin = origin
      self.currentUser = currentUser
      self.pages = drafts.map { MediaSummaryPageState(draft: $0) }
      let clampedIndex = drafts.isEmpty ? 0 : min(max(0, selectedIndex), drafts.count - 1)
      self.selectedIndex = clampedIndex
      self.isMarkerPlacementMode = isMarkerPlacementMode
      self.isSaving = isSaving
      self.errorMessage = errorMessage
      self.now = now
    }
  }

  public enum Action: Equatable, Sendable {
    case task
    case pageSelected(Int)
    case toggleMarkerPlacementMode
    case markerAddedAt(x: Double, y: Double)
    case markerSelected(Int)
    case markerSelectionCleared
    case markerDeleted(Int)
    case descriptionChanged(String)
    case retakeTapped
    case cancelTapped
    case saveTapped(mode: MediaSummarySaveMode, captureAnother: Bool)
    case saveSucceeded(mode: MediaSummarySaveMode, captureAnother: Bool)
    case saveFailed(String)
    case dismissError
    case delegate(Delegate)

    @CasePathable
    public enum Delegate: Equatable, Sendable {
      case didSave(mode: MediaSummarySaveMode, captureAnother: Bool)
      case didRequestRetake(CaptureSourceKind)
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
      case .toggleMarkerPlacementMode:
        state.isMarkerPlacementMode.toggle()
        return .none
      case .markerAddedAt(let x, let y):
        return addMarker(&state, x: x, y: y)
      case .markerSelected(let number):
        return selectMarker(&state, number: number)
      case .markerSelectionCleared:
        return clearMarkerSelection(&state)
      case .markerDeleted(let number):
        return deleteMarker(&state, number: number)
      case .descriptionChanged(let value):
        return updateDescription(&state, value: value)
      case .retakeTapped:
        return discardAndEmit(&state, delegate: .didRequestRetake(state.origin))
      case .cancelTapped:
        return discardAndEmit(&state, delegate: .didCancel)
      case .saveTapped(let mode, let captureAnother):
        return startSave(&state, mode: mode, captureAnother: captureAnother)
      case .saveSucceeded(let mode, let captureAnother):
        return finishSave(&state, mode: mode, captureAnother: captureAnother)
      case .saveFailed(let message):
        state.isSaving = false
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
}
