import AppConfigClient
import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import MediaStorage

@Reducer
public struct CaptureFeature: Sendable {
  @ObservableState
  public struct State: Equatable, Sendable {
    public let apartmentId: String
    public let source: CaptureSourceKind
    public var isLocationPromptPresented: Bool
    public var isPickerPresented: Bool
    public var isPickerDismissalSettled: Bool
    public var isProcessing: Bool
    public var pendingDeviceLocation: CaptureLocationMetadata?
    public var pendingDrafts: [CapturedPhotoDraft]?
    public var shouldPresentCameraAfterPrompt: Bool
    public var errorMessage: String?

    public init(
      apartmentId: String,
      source: CaptureSourceKind,
      isLocationPromptPresented: Bool = false,
      isPickerPresented: Bool = false,
      isPickerDismissalSettled: Bool = false,
      isProcessing: Bool = false,
      pendingDeviceLocation: CaptureLocationMetadata? = nil,
      pendingDrafts: [CapturedPhotoDraft]? = nil,
      shouldPresentCameraAfterPrompt: Bool = false,
      errorMessage: String? = nil
    ) {
      self.apartmentId = apartmentId
      self.source = source
      self.isLocationPromptPresented = isLocationPromptPresented
      self.isPickerPresented = isPickerPresented
      self.isPickerDismissalSettled = isPickerDismissalSettled
      self.isProcessing = isProcessing
      self.pendingDeviceLocation = pendingDeviceLocation
      self.pendingDrafts = pendingDrafts
      self.shouldPresentCameraAfterPrompt = shouldPresentCameraAfterPrompt
      self.errorMessage = errorMessage
    }
  }

  public enum Action: Equatable, Sendable {
    case start
    case allowLocationTapped
    case skipLocationTapped
    case locationPromptDidDismiss
    case locationResolved(CaptureLocationMetadata?)
    case photoSelectionStarted
    case cameraPhotoCaptured(Data)
    case importedPhotosSelected([Data])
    case pickerCancelled
    case pickerDismissed
    case pickerDismissalSettled
    case ingestSucceeded([CapturedPhotoDraft])
    case ingestFailed(String)
    case dismissError
    case cancelTapped
    case delegate(Delegate)

    @CasePathable
    public enum Delegate: Equatable, Sendable {
      case didFinishCapture([CapturedPhotoDraft], origin: CaptureSourceKind)
      case didCancel
    }
  }

  enum CancelID: Hashable, Sendable {
    case settle
    case location
    case ingest
  }

  @Dependency(\.locationCapture) var locationCapture
  @Dependency(\.mediaStorage) var mediaStorage
  @Dependency(\.appConfigClient) var appConfigClient
  @Dependency(\.idGenerator) var idGenerator
  @Dependency(\.haptics) var haptics
  @Dependency(\.date.now) var now
  @Dependency(\.timeZone) var timeZone
  @Dependency(\.continuousClock) var clock

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .start:
        return handleStart(&state)
      case .allowLocationTapped, .skipLocationTapped, .locationPromptDidDismiss, .locationResolved:
        return handleLocationAction(&state, action: action)
      case .photoSelectionStarted:
        state.isProcessing = true
        return .none
      case .cameraPhotoCaptured(let rawData):
        return handleCameraCapture(&state, rawData: rawData)
      case .importedPhotosSelected(let rawItems):
        return handleImportedPhotos(&state, rawItems: rawItems)
      case .pickerCancelled, .pickerDismissed, .pickerDismissalSettled, .cancelTapped:
        return handlePresentationLifecycle(&state, action: action)
      case .ingestSucceeded(let drafts):
        state.isProcessing = false
        state.pendingDrafts = drafts
        return .merge(
          .run { _ in
            await haptics.actionSucceeded()
          },
          finishIfReady(&state)
        )
      case .ingestFailed(let message):
        state.isPickerPresented = false
        state.isProcessing = false
        state.errorMessage = message
        let settleEffect: Effect<Action> =
          (state.source != .camera && !state.isPickerDismissalSettled)
          ? schedulePresentationSettle()
          : .none
        return .merge(
          settleEffect,
          .run { _ in
            await haptics.error()
          }
        )
      case .dismissError:
        state.errorMessage = nil
        return .send(.delegate(.didCancel))
      case .delegate:
        return .none
      }
    }
  }
}
