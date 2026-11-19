import APIClient
import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import SyncEngine

extension ApartmentsListFeature {
  func startSync(_ state: inout State) -> Effect<Action> {
    guard !state.isSyncing else {
      return .none
    }
    state.isSyncing = true
    state.errorMessage = nil
    return .run { send in
      if let snapshot = try? ApartmentsListStore.fetchSnapshot(from: database) {
        await send(.localDataLoaded(user: snapshot.user, items: snapshot.items))
      }
      do {
        // Decision Q6 & S2-8: Flush pending local apartment creations before pulling remote state.
        _ = await syncEngine.processOutbox()
        _ = try await syncEngine.syncAllOnEntry()
        let updated = try ApartmentsListStore.fetchSnapshot(from: database)
        await send(.syncCompleted(user: updated.user, items: updated.items))
      } catch {
        await send(.syncFailed(mapError(error)))
      }
    }
  }

  func listenToSyncEvents() -> Effect<Action> {
    .run { send in
      let stream = await syncEngine.events()
      for await event in stream {
        await send(.syncEventReceived(event))
      }
    }
    .cancellable(id: CancelID.syncEvents, cancelInFlight: true)
  }

  func handleSyncEvent(_ event: SyncEvent) -> Effect<Action> {
    switch event {
    case .apartmentSynced, .outboxCompleted, .quotaExceeded:
      return .run { send in
        if let snapshot = try? ApartmentsListStore.fetchSnapshot(from: database) {
          await send(.localDataLoaded(user: snapshot.user, items: snapshot.items))
        }
      }
    case .uploadProgress, .forceUpdateRequired:
      return .none
    }
  }

  func handleCreateAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .createMenuTapped:
      state.createSheet = CreateApartmentSheetState()
      return .none
    case .createSheetDismissed:
      state.createSheet = nil
      return .none
    case .createNameChanged(let value):
      state.createSheet?.name = value
      state.createSheet?.errorMessage = nil
      return .none
    case .createStreetChanged(let value):
      state.createSheet?.street = value
      state.createSheet?.errorMessage = nil
      return .none
    case .createCityChanged(let value):
      state.createSheet?.city = value
      state.createSheet?.errorMessage = nil
      return .none
    case .createSubmitted:
      return submitCreate(&state)
    case .createSucceeded(let user, let items):
      state.createSheet = nil
      state.currentUser = user
      state.items = items
      return .run { _ in
        await haptics.actionSucceeded()
      }
    case .createFailed(let message):
      state.createSheet?.isSaving = false
      state.createSheet?.errorMessage = message
      return .run { _ in
        await haptics.error()
      }
    default:
      return .none
    }
  }

  private func submitCreate(_ state: inout State) -> Effect<Action> {
    guard let sheet = state.createSheet, !sheet.isSaving else {
      return .none
    }
    switch ApartmentsListStore.validateCreateInput(
      name: sheet.name,
      street: sheet.street,
      city: sheet.city
    ) {
    case .failure(let failure):
      state.createSheet?.errorMessage = failure.message
      return .run { _ in
        await haptics.warning()
      }
    case .success(let input):
      state.createSheet?.isSaving = true
      state.createSheet?.errorMessage = nil
      let currentTime = now
      return .run { send in
        do {
          try await persistAndSyncNewApartment(input: input, currentTime: currentTime)
          let snapshot = try ApartmentsListStore.fetchSnapshot(from: database)
          await send(.createSucceeded(user: snapshot.user, items: snapshot.items))
        } catch {
          await send(.createFailed(mapError(error)))
        }
      }
    }
  }

  private func persistAndSyncNewApartment(
    input: CreateApartmentInput,
    currentTime: Date
  ) async throws {
    let store = ApartmentMutationStore(database: database)
    guard let user = try store.fetchCurrentUser() else {
      throw MissingUserProfileError()
    }
    let apartment = Apartment(
      id: idGenerator.generate(),
      ownerId: user.id,
      name: input.name,
      street: input.street,
      city: input.city,
      role: .owner,
      createdAt: currentTime,
      updatedAt: currentTime
    )
    let creator = ApartmentMember(
      userId: user.id,
      displayName: user.displayName,
      shortTag: user.shortTag,
      color: user.color,
      role: .owner,
      joinedAt: currentTime
    )
    // Decision Q6 & S2-8: Persist apartment locally with UUIDv7 before background outbox sync.
    try store.createApartment(
      apartment, creator: creator, outboxId: idGenerator.generate(), now: currentTime)
    _ = await syncEngine.processOutbox()
  }

  func mapError(_ error: any Error) -> String {
    if error is MissingUserProfileError {
      return L10n.errorMessage(for: .userNotFound)
    }
    if let problem = error as? APIProblemError {
      return L10n.errorMessage(for: problem.code)
    }
    return L10n.errorMessage(for: .unknown("APARTMENTS_LIST_ERROR"))
  }
}

private struct MissingUserProfileError: Error {}
