import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import MediaStorage

extension CaptureFeature {
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
        let request = PhotoIngestRequest(
          mediaId: idGenerator.generate(),
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
    .cancellable(id: CancelID.ingest, cancelInFlight: true)
  }

  func handleImportedPhotos(_ state: inout State, rawItems: [Data]) -> Effect<Action> {
    state.isPickerPresented = false
    guard !rawItems.isEmpty else {
      state.isProcessing = false
      return state.isPickerDismissalSettled ? finishIfReady(&state) : schedulePresentationSettle()
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
          let request = PhotoIngestRequest(
            mediaId: idGenerator.generate(),
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
    .cancellable(id: CancelID.ingest, cancelInFlight: true)
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
