import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation

extension MediaDetailFeature {
  func handleMutationAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .entryDeleteTapped, .entryDeleteConfirmationDismissed, .entryDeleteConfirmed,
      .entryDeleteSucceeded, .entryDeleteFailed:
      return handleEntryDeleteAction(&state, action: action)
    case .metadataTapped:
      state.isMetadataSheetPresented = true
      return .none
    case .metadataDismissed:
      state.isMetadataSheetPresented = false
      return .none
    case .mediaDeleteTapped, .mediaDeleteConfirmationDismissed, .mediaDeleteSheetDidDismiss,
      .mediaDeleteConfirmed, .mediaHardDeleteSucceeded, .mediaSoftDeleteSucceeded,
      .mediaDeleteFailed:
      return handleMediaDeleteAction(&state, action: action)
    default:
      return .none
    }
  }

  private func handleEntryDeleteAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .entryDeleteTapped(let entryId):
      guard let item = state.entries.first(where: { $0.id == entryId }) else {
        return .none
      }
      if state.canEditOrHardDeleteEntry(item) {
        state.entryDeleteConfirmation = .hardDeleteLocal(entryId: entryId)
      } else if state.canRetractEntry(item) {
        state.entryDeleteConfirmation = .retractSynced(entryId: entryId)
      }
      return .none
    case .entryDeleteConfirmationDismissed:
      state.entryDeleteConfirmation = nil
      return .none
    case .entryDeleteConfirmed:
      return confirmEntryDelete(&state)
    case .entryDeleteSucceeded(let snapshot, let shouldSyncOutbox):
      state.entryDeleteConfirmation = nil
      applySnapshot(snapshot, to: &state)
      return .merge(
        .run { _ in
          await haptics.actionSucceeded()
        },
        shouldSyncOutbox
          ? .run { _ in
            _ = await syncEngine.processOutbox()
          }
          : .none
      )
    case .entryDeleteFailed(let message):
      state.entryDeleteConfirmation = nil
      state.errorMessage = message
      return .run { _ in
        await haptics.error()
      }
    default:
      return .none
    }
  }

  private func confirmEntryDelete(_ state: inout State) -> Effect<Action> {
    guard let confirmation = state.entryDeleteConfirmation, let actorId = state.currentUser?.userId
    else {
      return .none
    }
    let mediaId = state.mediaId
    let timestamp = now
    let generator = idGenerator

    return .run { send in
      do {
        let entryStore = EntryMutationStore(database: database)
        let shouldSyncOutbox: Bool
        switch confirmation {
        case .hardDeleteLocal(let entryId):
          try entryStore.hardDeleteLocalEntry(entryId: entryId, actorId: actorId)
          shouldSyncOutbox = false
        case .retractSynced(let entryId):
          try entryStore.retractSyncedEntry(
            entryId: entryId,
            actorId: actorId,
            outboxId: generator.generate(),
            now: timestamp
          )
          shouldSyncOutbox = true
        }
        let updated = try MediaDetailStore.fetchSnapshot(mediaId: mediaId, from: database)
        await send(.entryDeleteSucceeded(updated, shouldSyncOutbox: shouldSyncOutbox))
      } catch {
        await send(.entryDeleteFailed(L10n.errorMessage(for: error)))
      }
    }
  }

  private func handleMediaDeleteAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .mediaDeleteTapped:
      guard state.canDeleteMedia, let media = state.media else {
        return .none
      }
      state.mediaDeleteConfirmation =
        media.isVerified ? .softDeleteSynced : .hardDeleteLocal
      return .none
    case .mediaDeleteConfirmationDismissed:
      state.mediaDeleteConfirmation = nil
      return .none
    case .mediaDeleteSheetDidDismiss:
      guard state.pendingHardDeleteDismiss else {
        return .none
      }
      state.pendingHardDeleteDismiss = false
      return .merge(
        .cancel(id: CancelID.syncEvents),
        .run { _ in
          await haptics.actionSucceeded()
        },
        .send(.delegate(.didDeleteLocalMedia(mediaId: state.mediaId)))
      )
    case .mediaDeleteConfirmed:
      return confirmMediaDelete(&state)
    case .mediaHardDeleteSucceeded:
      state.mediaDeleteConfirmation = nil
      state.pendingHardDeleteDismiss = true
      return .none
    case .mediaSoftDeleteSucceeded(let snapshot):
      state.mediaDeleteConfirmation = nil
      state.composer = nil
      applySnapshot(snapshot, to: &state)
      return .merge(
        .run { _ in
          await haptics.actionSucceeded()
        },
        .run { _ in
          _ = await syncEngine.processOutbox()
        }
      )
    case .mediaDeleteFailed(let message):
      state.mediaDeleteConfirmation = nil
      state.errorMessage = message
      return .run { _ in
        await haptics.error()
      }
    default:
      return .none
    }
  }

  private func confirmMediaDelete(_ state: inout State) -> Effect<Action> {
    guard
      let mode = state.mediaDeleteConfirmation,
      let actorId = state.currentUser?.userId
    else {
      return .none
    }
    let mediaId = state.mediaId
    let timestamp = now
    let generator = idGenerator

    return .run { send in
      do {
        let mediaStore = MediaMutationStore(database: database)
        switch mode {
        case .hardDeleteLocal:
          _ = try mediaStore.hardDeleteLocalMedia(mediaId: mediaId, actorId: actorId)
          try? mediaStorage.deleteLocalFile(mediaId)
          await send(.mediaHardDeleteSucceeded)
        case .softDeleteSynced:
          try mediaStore.softDeleteSyncedMedia(
            mediaId: mediaId,
            actorId: actorId,
            outboxId: generator.generate(),
            now: timestamp
          )
          let updated = try MediaDetailStore.fetchSnapshot(mediaId: mediaId, from: database)
          await send(.mediaSoftDeleteSucceeded(updated))
        }
      } catch {
        await send(.mediaDeleteFailed(L10n.errorMessage(for: error)))
      }
    }
  }
}
