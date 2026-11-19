import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import MediaStorage

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
    let status = locationCapture.authorizationStatus()
    switch status {
    case .notDetermined where !locationCapture.hasDismissedPrompt():
      state.isLocationPromptPresented = true
      return .none
    case .authorized:
      state.isPickerPresented = true
      return .run { send in
        let location = await locationCapture.captureCurrentLocation()
        await send(.locationResolved(location))
      }
    case .notDetermined, .denied, .restricted:
      state.isPickerPresented = true
      return .none
    }
  }

  func handleAllowLocation(_ state: inout State) -> Effect<Action> {
    state.isLocationPromptPresented = false
    return .run { send in
      locationCapture.markPromptDismissed()
      let updatedStatus = await locationCapture.requestWhenInUseAuthorization()
      let location: CaptureLocationMetadata? =
        updatedStatus == .authorized ? await locationCapture.captureCurrentLocation() : nil
      await send(.locationResolved(location))
    }
  }

  func handleSkipLocation(_ state: inout State) -> Effect<Action> {
    state.isLocationPromptPresented = false
    state.isPickerPresented = true
    return .run { _ in
      locationCapture.markPromptDismissed()
    }
  }

  func handleCameraCapture(_ state: inout State, rawData: Data) -> Effect<Action> {
    state.isPickerPresented = false
    state.isProcessing = true
    state.errorMessage = nil
    let apartmentId = state.apartmentId
    let origin = state.source
    let deviceLocation = state.pendingDeviceLocation
    let captureDate = now
    let tzIdentifier = timeZone.identifier
    let compression = appConfigClient.loadCachedOrDefault().jpegCompression

    return .run { send in
      do {
        let mediaId = idGenerator.generate()
        let request = PhotoIngestRequest(
          mediaId: mediaId,
          rawData: rawData,
          source: .camera,
          compression: compression,
          deviceLocation: deviceLocation,
          now: captureDate,
          timeZoneIdentifier: tzIdentifier
        )
        let artifact = try mediaStorage.ingestPhoto(request)
        let draft = makeDraft(
          from: artifact,
          apartmentId: apartmentId,
          origin: origin,
          source: .camera
        )
        await send(.ingestSucceeded([draft]))
      } catch {
        await send(.ingestFailed(L10n.string("capture.import.failed")))
      }
    }
  }

  func handleImportedPhotos(_ state: inout State, rawItems: [Data]) -> Effect<Action> {
    state.isPickerPresented = false
    guard !rawItems.isEmpty else {
      return .send(.delegate(.didCancel))
    }

    state.isProcessing = true
    state.errorMessage = nil
    let apartmentId = state.apartmentId
    let origin = state.source
    let importDate = now
    let tzIdentifier = timeZone.identifier
    let compression = appConfigClient.loadCachedOrDefault().jpegCompression

    return .run { send in
      var drafts: [CapturedPhotoDraft] = []
      drafts.reserveCapacity(rawItems.count)
      do {
        for rawData in rawItems {
          let mediaId = idGenerator.generate()
          let request = PhotoIngestRequest(
            mediaId: mediaId,
            rawData: rawData,
            source: .imported,
            compression: compression,
            deviceLocation: nil,
            now: importDate,
            timeZoneIdentifier: tzIdentifier
          )
          let artifact = try mediaStorage.ingestPhoto(request)
          drafts.append(
            makeDraft(
              from: artifact,
              apartmentId: apartmentId,
              origin: origin,
              source: .imported
            )
          )
        }
        await send(.ingestSucceeded(drafts))
      } catch {
        for draft in drafts {
          try? mediaStorage.deleteLocalFile(draft.id)
        }
        await send(.ingestFailed(L10n.string("capture.import.failed")))
      }
    }
  }

  private func makeDraft(
    from artifact: ProcessedPhotoArtifact,
    apartmentId: String,
    origin: CaptureSourceKind,
    source: MediaSource
  ) -> CapturedPhotoDraft {
    CapturedPhotoDraft(
      id: artifact.mediaId,
      apartmentId: apartmentId,
      origin: origin,
      source: source,
      localFilePath: artifact.localFilePath,
      sha256: artifact.sha256,
      width: artifact.width,
      height: artifact.height,
      bytes: artifact.bytes,
      capturedAt: artifact.capturedAt,
      capturedTz: artifact.capturedTz,
      capturedAtFromImport: artifact.capturedAtFromImport,
      location: artifact.location
    )
  }
}
