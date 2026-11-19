import APIClient
import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import SyncEngine

extension ApartmentTimelineFeature {
  func handleSyncAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .task:
      state.now = now
      state.quotaLimit = appConfigClient.loadCachedOrDefault().cloudMediaQuotaPerApartment
      return .merge(startSync(&state), listenToSyncEvents())
    case .pulledToRefresh:
      state.now = now
      return startSync(&state)
    case .reloadLocalState:
      state.now = now
      return reloadLocalSnapshot(apartmentId: state.apartmentId)
    case .localSnapshotLoaded(let snapshot):
      applySnapshot(snapshot, to: &state)
      return .none
    case .syncCompleted(let snapshot):
      state.isSyncing = false
      applySnapshot(snapshot, to: &state)
      return .none
    case .syncFailed(let message):
      state.isSyncing = false
      state.errorMessage = message
      return .none
    case .syncEventReceived(let event):
      return handleSyncEvent(&state, event: event)
    case .syncAllLocalTapped, .syncAllLocalCompleted, .syncAllLocalFailed:
      return handleSyncAllLocalAction(&state, action: action)
    default:
      return .none
    }
  }

  private func handleSyncAllLocalAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .syncAllLocalTapped:
      return startSyncAllLocal(&state)
    case .syncAllLocalCompleted(let snapshot):
      state.isSyncingAllLocal = false
      applySnapshot(snapshot, to: &state)
      return .run { _ in await haptics.actionSucceeded() }
    case .syncAllLocalFailed(let message):
      state.isSyncingAllLocal = false
      state.errorMessage = message
      return .run { _ in await haptics.error() }
    default:
      return .none
    }
  }

  func applySnapshot(_ snapshot: ApartmentTimelineSnapshot, to state: inout State) {
    state.apartment = snapshot.apartment
    state.sections = snapshot.sections
    state.localUnsyncedCount = snapshot.localUnsyncedCount
    state.cloudMediaCount = snapshot.cloudMediaCount
  }

  func startSync(_ state: inout State) -> Effect<Action> {
    guard !state.isSyncing else {
      return .none
    }
    state.isSyncing = true
    state.errorMessage = nil
    let apartmentId = state.apartmentId
    let currentTime = now
    let activeCalendar = calendar
    let activeTimeZone = timeZone

    return .run { send in
      if let snapshot = try? ApartmentTimelineStore.fetchSnapshot(
        apartmentId: apartmentId, from: database, now: currentTime,
        calendar: activeCalendar, timeZone: activeTimeZone
      ) {
        await send(.localSnapshotLoaded(snapshot))
      }
      do {
        // Decision Q6 & S2-8: Flush pending local apartment creations before pulling changes.
        _ = await syncEngine.processOutbox()
        _ = try await syncEngine.syncApartment(apartmentId)
        let updated = try ApartmentTimelineStore.fetchSnapshot(
          apartmentId: apartmentId, from: database, now: currentTime,
          calendar: activeCalendar, timeZone: activeTimeZone
        )
        await send(.syncCompleted(updated))
      } catch {
        await send(.syncFailed(mapError(error)))
      }
    }
  }

  private func listenToSyncEvents() -> Effect<Action> {
    .run { send in
      let stream = await syncEngine.events()
      for await event in stream {
        await send(.syncEventReceived(event))
      }
    }
    .cancellable(id: CancelID.syncEvents, cancelInFlight: true)
  }

  private func handleSyncEvent(_ state: inout State, event: SyncEvent) -> Effect<Action> {
    switch event {
    case .uploadProgress(let mediaId, let fractionCompleted):
      state.uploadProgressByMediaId[mediaId] = fractionCompleted
      return .none
    case .quotaExceeded(let apartmentId, let mediaId):
      guard apartmentId == state.apartmentId else {
        return .none
      }
      state.uploadProgressByMediaId[mediaId] = nil
      // Decision S2-4/5: Confirm the local copy remains safe when the 250-photo quota is reached.
      state.quotaNoticeMessage = L10n.string("media.summary.quota.notice")
      return .merge(
        reloadLocalSnapshot(apartmentId: state.apartmentId),
        .run { _ in await haptics.warning() }
      )
    case .apartmentSynced(let apartmentId, _):
      guard apartmentId == state.apartmentId else {
        return .none
      }
      return reloadLocalSnapshot(apartmentId: state.apartmentId)
    case .outboxCompleted:
      state.uploadProgressByMediaId = [:]
      return reloadLocalSnapshot(apartmentId: state.apartmentId)
    case .forceUpdateRequired:
      return .none
    }
  }

  private func startSyncAllLocal(_ state: inout State) -> Effect<Action> {
    guard !state.isSyncingAllLocal, state.localUnsyncedCount > 0 else {
      return .none
    }
    state.isSyncingAllLocal = true
    state.errorMessage = nil
    let apartmentId = state.apartmentId
    let currentTime = now
    let activeCalendar = calendar
    let activeTimeZone = timeZone

    return .run { send in
      do {
        // Decision S2-7: Manual batch sync queues every local-only photo and flushes the outbox.
        _ = try await syncEngine.enqueueAllLocalMedia(apartmentId)
        _ = await syncEngine.processOutbox()
        let updated = try ApartmentTimelineStore.fetchSnapshot(
          apartmentId: apartmentId, from: database, now: currentTime,
          calendar: activeCalendar, timeZone: activeTimeZone
        )
        await send(.syncAllLocalCompleted(updated))
      } catch {
        await send(.syncAllLocalFailed(mapError(error)))
      }
    }
  }

  func reloadLocalSnapshot(apartmentId: String) -> Effect<Action> {
    let currentTime = now
    let activeCalendar = calendar
    let activeTimeZone = timeZone
    return .run { send in
      if let snapshot = try? ApartmentTimelineStore.fetchSnapshot(
        apartmentId: apartmentId, from: database, now: currentTime,
        calendar: activeCalendar, timeZone: activeTimeZone
      ) {
        await send(.localSnapshotLoaded(snapshot))
      }
    }
  }

  func mapError(_ error: any Error) -> String {
    L10n.errorMessage(for: error)
  }
}
