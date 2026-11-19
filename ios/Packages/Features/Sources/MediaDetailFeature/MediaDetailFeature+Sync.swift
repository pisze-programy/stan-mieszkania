import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import SyncEngine

extension MediaDetailFeature {
  func handleSyncAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .task:
      state.now = now
      return startInitialLoad(&state)
    case .snapshotLoaded(let snapshot):
      applySnapshot(snapshot, to: &state)
      return .none
    case .photoCacheReady:
      state.isPhotoCached = true
      return .none
    case .syncEventReceived(let event):
      return handleSyncEvent(&state, event: event)
    case .uploadToCloudTapped:
      return startSinglePhotoUpload(&state)
    case .uploadToCloudFinished(let snapshot):
      state.isUploadingToCloud = false
      applySnapshot(snapshot, to: &state)
      return .run { _ in
        await haptics.actionSucceeded()
      }
    case .uploadToCloudFailed(let message):
      state.isUploadingToCloud = false
      state.errorMessage = message
      return .run { _ in
        await haptics.error()
      }
    default:
      return .none
    }
  }

  func applySnapshot(_ snapshot: MediaDetailSnapshot, to state: inout State) {
    state.media = snapshot.media
    state.mediaAuthorName = snapshot.mediaAuthorName
    state.mediaAuthorColorHex = snapshot.mediaAuthorColorHex
    state.entries = snapshot.entries
    state.currentUser = snapshot.currentUser
    state.hasOtherMembers = snapshot.hasOtherMembers
    if let selected = state.selectedMarkerNumber, state.entryId(owningMarker: selected) == nil {
      state.selectedMarkerNumber = nil
    }
  }

  private func startInitialLoad(_ state: inout State) -> Effect<Action> {
    let mediaId = state.mediaId
    let apartmentId = state.apartmentId
    let loadAndCache: Effect<Action> = .run { send in
      guard let snapshot = try? MediaDetailStore.fetchSnapshot(mediaId: mediaId, from: database)
      else {
        return
      }
      await send(.snapshotLoaded(snapshot))

      guard let media = snapshot.media, !media.isSoftDeleted else {
        return
      }
      if mediaStorage.fileExists(mediaId) {
        await send(.photoCacheReady)
      } else if media.isVerified {
        if (try? await syncEngine.ensurePhotoCached(apartmentId, mediaId, media.sha256)) != nil {
          await send(.photoCacheReady)
        }
      }
    }

    let eventStream: Effect<Action> = .run { send in
      let stream = await syncEngine.events()
      for await event in stream {
        await send(.syncEventReceived(event))
      }
    }
    .cancellable(id: CancelID.syncEvents, cancelInFlight: true)

    return .merge(loadAndCache, eventStream)
  }

  private func handleSyncEvent(_ state: inout State, event: SyncEvent) -> Effect<Action> {
    switch event {
    case .uploadProgress(let eventMediaId, let fraction):
      guard eventMediaId == state.mediaId else {
        return .none
      }
      state.uploadProgress = fraction
      return .none
    case .quotaExceeded(let eventApartmentId, let eventMediaId):
      guard eventApartmentId == state.apartmentId, eventMediaId == state.mediaId else {
        return .none
      }
      state.uploadProgress = nil
      state.isUploadingToCloud = false
      // Decision S2-4/5: Confirm local copy stays safe when 250-photo quota is reached.
      state.quotaNoticeMessage = L10n.string("media.summary.quota.notice")
      return .merge(
        reloadSnapshot(mediaId: state.mediaId),
        .run { _ in
          await haptics.warning()
        }
      )
    case .apartmentSynced(let eventApartmentId, _):
      guard eventApartmentId == state.apartmentId else {
        return .none
      }
      return reloadSnapshot(mediaId: state.mediaId)
    case .outboxCompleted:
      state.uploadProgress = nil
      return reloadSnapshot(mediaId: state.mediaId)
    case .forceUpdateRequired:
      return .none
    }
  }

  // Decision S2-7: Manual single-photo upload queues media + its local draft entries.
  private func startSinglePhotoUpload(_ state: inout State) -> Effect<Action> {
    guard state.canUploadToCloud, !state.isUploadingToCloud else {
      return .none
    }
    state.isUploadingToCloud = true
    state.errorMessage = nil
    let mediaId = state.mediaId
    return .run { send in
      do {
        try await syncEngine.enqueueMediaUpload(mediaId)
        _ = await syncEngine.processOutbox()
        let updated = try MediaDetailStore.fetchSnapshot(mediaId: mediaId, from: database)
        await send(.uploadToCloudFinished(updated))
      } catch {
        await send(.uploadToCloudFailed(L10n.errorMessage(for: error)))
      }
    }
  }

  func reloadSnapshot(mediaId: String) -> Effect<Action> {
    .run { send in
      if let snapshot = try? MediaDetailStore.fetchSnapshot(mediaId: mediaId, from: database) {
        await send(.snapshotLoaded(snapshot))
      }
    }
  }
}
