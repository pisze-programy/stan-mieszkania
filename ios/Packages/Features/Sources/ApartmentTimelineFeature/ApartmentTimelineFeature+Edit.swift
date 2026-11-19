import ComposableArchitecture
import Database
import Domain
import Foundation

extension ApartmentTimelineFeature {
  func handleEditAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .editMenuTapped:
      guard state.isOwner, let apartment = state.apartment else {
        return .none
      }
      state.editSheet = EditApartmentSheetState(
        name: apartment.name,
        street: apartment.street,
        city: apartment.city
      )
      return .none
    case .editSheetDismissed:
      state.editSheet = nil
      return .none
    case .editNameChanged(let value):
      state.editSheet?.name = value
      state.editSheet?.errorMessage = nil
      return .none
    case .editStreetChanged(let value):
      state.editSheet?.street = value
      state.editSheet?.errorMessage = nil
      return .none
    case .editCityChanged(let value):
      state.editSheet?.city = value
      state.editSheet?.errorMessage = nil
      return .none
    case .editSubmitted:
      return submitEdit(&state)
    case .editSucceeded(let snapshot):
      state.editSheet = nil
      applySnapshot(snapshot, to: &state)
      return .run { _ in
        await haptics.actionSucceeded()
      }
    case .editFailed(let message):
      state.editSheet?.isSaving = false
      state.editSheet?.errorMessage = message
      return .run { _ in
        await haptics.error()
      }
    default:
      return .none
    }
  }

  private func submitEdit(_ state: inout State) -> Effect<Action> {
    guard state.isOwner, let sheet = state.editSheet, !sheet.isSaving else {
      return .none
    }
    switch ApartmentTimelineStore.validateEditInput(
      name: sheet.name,
      street: sheet.street,
      city: sheet.city
    ) {
    case .failure(let failure):
      state.editSheet?.errorMessage = failure.message
      return .run { _ in
        await haptics.warning()
      }
    case .success(let validated):
      state.editSheet?.isSaving = true
      state.editSheet?.errorMessage = nil
      let apartmentId = state.apartmentId
      let fallbackOwnerId = state.apartment?.ownerId ?? ""
      let currentTime = now
      let activeCalendar = calendar
      let activeTimeZone = timeZone

      return .run { send in
        do {
          let store = ApartmentMutationStore(database: database)
          let authorId = (try store.fetchCurrentUser()?.id) ?? fallbackOwnerId
          // Decision S2-8 & S2-9: Owner edits record change history and enqueue outbox sync.
          try store.updateApartmentMetadata(
            ApartmentMetadataUpdate(
              apartmentId: apartmentId,
              name: validated.name,
              street: validated.street,
              city: validated.city,
              authorId: authorId
            ),
            outboxId: idGenerator.generate(),
            changeIDGenerator: { idGenerator.generate() },
            now: currentTime
          )
          _ = await syncEngine.processOutbox()
          let updated = try ApartmentTimelineStore.fetchSnapshot(
            apartmentId: apartmentId,
            from: database,
            calendar: activeCalendar,
            timeZone: activeTimeZone
          )
          await send(.editSucceeded(updated))
        } catch {
          await send(.editFailed(mapError(error)))
        }
      }
    }
  }
}
