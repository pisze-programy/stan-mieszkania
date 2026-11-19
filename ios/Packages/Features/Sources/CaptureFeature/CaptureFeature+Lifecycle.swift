import ComposableArchitecture
import DesignSystem
import Domain
import Foundation

extension CaptureFeature {
  func handleStart(_ state: inout State) -> Effect<Action> {
    guard !state.isPickerPresented, !state.isLocationPromptPresented, !state.isProcessing else {
      return .none
    }

    guard state.source == .camera else {
      state.isPickerPresented = true
      return .none
    }

    // Decision Q10: Show optional GPS explanation once when undetermined; never block capture.
    switch locationCapture.authorizationStatus() {
    case .notDetermined where !locationCapture.hasDismissedPrompt():
      state.isLocationPromptPresented = true
      return .none
    case .authorized:
      state.isPickerPresented = true
      return .run { send in
        let location = await locationCapture.captureCurrentLocation()
        await send(.locationResolved(location))
      }
      .cancellable(id: CancelID.location, cancelInFlight: true)
    case .notDetermined, .denied, .restricted:
      state.isPickerPresented = true
      return .none
    }
  }

  func handleLocationAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .allowLocationTapped:
      state.isLocationPromptPresented = false
      state.shouldPresentCameraAfterPrompt = true
      return .run { send in
        locationCapture.markPromptDismissed()
        let updatedStatus = await locationCapture.requestWhenInUseAuthorization()
        let location: CaptureLocationMetadata? =
          updatedStatus == .authorized ? await locationCapture.captureCurrentLocation() : nil
        await send(.locationResolved(location))
      }
      .cancellable(id: CancelID.location, cancelInFlight: true)
    case .skipLocationTapped:
      state.isLocationPromptPresented = false
      state.shouldPresentCameraAfterPrompt = true
      return .run { _ in
        locationCapture.markPromptDismissed()
      }
    case .locationPromptDidDismiss:
      state.isLocationPromptPresented = false
      let shouldOpenCamera = state.shouldPresentCameraAfterPrompt
      state.shouldPresentCameraAfterPrompt = false
      guard
        shouldOpenCamera,
        state.source == .camera,
        !state.isPickerPresented,
        !state.isProcessing
      else {
        return .none
      }
      state.isPickerPresented = true
      return .none
    case .locationResolved(let location):
      state.pendingDeviceLocation = location
      return .none
    default:
      return .none
    }
  }

  func handlePresentationLifecycle(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .pickerCancelled:
      state.isPickerPresented = false
      guard state.source != .camera else {
        return .none
      }
      if state.isPickerDismissalSettled {
        return finishIfReady(&state)
      }
      return schedulePresentationSettle()
    case .pickerDismissed:
      state.isPickerPresented = false
      guard state.source != .camera else {
        return .none
      }
      return schedulePresentationSettle()
    case .pickerDismissalSettled:
      state.isPickerDismissalSettled = true
      return finishIfReady(&state)
    case .cancelTapped:
      state.isPickerPresented = false
      state.isLocationPromptPresented = false
      state.errorMessage = nil
      return .send(.delegate(.didCancel))
    default:
      return .none
    }
  }

  func finishIfReady(_ state: inout State) -> Effect<Action> {
    // UIKit invariant: emit follow-up presentations only after the picker dismissal settles.
    guard state.isPickerDismissalSettled else {
      return .none
    }
    if let drafts = state.pendingDrafts {
      state.pendingDrafts = nil
      return .send(.delegate(.didFinishCapture(drafts, origin: state.source)))
    }
    if !state.isProcessing && state.errorMessage == nil {
      return .send(.delegate(.didCancel))
    }
    return .none
  }

  func schedulePresentationSettle() -> Effect<Action> {
    .run { send in
      try await clock.sleep(for: CaptureConstants.presentationSettleDelay)
      await send(.pickerDismissalSettled)
    }
    .cancellable(id: CancelID.settle, cancelInFlight: true)
  }
}
