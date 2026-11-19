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
    public var isProcessing: Bool
    public var pendingDeviceLocation: CaptureLocationMetadata?
    public var errorMessage: String?

    public init(
      apartmentId: String,
      source: CaptureSourceKind,
      isLocationPromptPresented: Bool = false,
      isPickerPresented: Bool = false,
      isProcessing: Bool = false,
      pendingDeviceLocation: CaptureLocationMetadata? = nil,
      errorMessage: String? = nil
    ) {
      self.apartmentId = apartmentId
      self.source = source
      self.isLocationPromptPresented = isLocationPromptPresented
      self.isPickerPresented = isPickerPresented
      self.isProcessing = isProcessing
      self.pendingDeviceLocation = pendingDeviceLocation
      self.errorMessage = errorMessage
    }
  }

  public enum Action: Equatable, Sendable {
    case task
    case allowLocationTapped
    case skipLocationTapped
    case locationResolved(CaptureLocationMetadata?)
    case cameraPhotoCaptured(Data)
    case importedPhotosSelected([Data])
    case pickerCancelled
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

  @Dependency(\.locationCapture) var locationCapture
  @Dependency(\.mediaStorage) var mediaStorage
  @Dependency(\.appConfigClient) var appConfigClient
  @Dependency(\.idGenerator) var idGenerator
  @Dependency(\.haptics) var haptics
  @Dependency(\.date.now) var now
  @Dependency(\.timeZone) var timeZone

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        return handleStart(&state)
      case .allowLocationTapped:
        return handleAllowLocation(&state)
      case .skipLocationTapped:
        return handleSkipLocation(&state)
      case .locationResolved(let location):
        state.pendingDeviceLocation = location
        if state.source == .camera, !state.isProcessing, !state.isPickerPresented {
          state.isPickerPresented = true
        }
        return .none
      case .cameraPhotoCaptured(let rawData):
        return handleCameraCapture(&state, rawData: rawData)
      case .importedPhotosSelected(let rawItems):
        return handleImportedPhotos(&state, rawItems: rawItems)
      case .pickerCancelled, .cancelTapped:
        state.isPickerPresented = false
        state.isLocationPromptPresented = false
        return .send(.delegate(.didCancel))
      case .ingestSucceeded(let drafts):
        state.isProcessing = false
        return .merge(
          .run { _ in
            await haptics.actionSucceeded()
          },
          .send(.delegate(.didFinishCapture(drafts, origin: state.source)))
        )
      case .ingestFailed(let message):
        state.isProcessing = false
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
