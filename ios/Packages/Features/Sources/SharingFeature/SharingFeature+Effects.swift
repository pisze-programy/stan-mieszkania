import APIClient
import ComposableArchitecture
import DesignSystem
import Domain
import Foundation

extension SharingFeature {
  func loadSharingData(_ state: inout State) -> Effect<Action> {
    guard !state.isLoading else {
      return .none
    }
    state.isLoading = true
    state.errorMessage = nil
    let apartmentId = state.apartmentId
    return .run { send in
      let cached = try? SharingStore.fetchCachedState(apartmentId: apartmentId, from: database)
      if let cached {
        await send(.localDataLoaded(apartment: cached.apartment, members: cached.members))
      }

      // Decision S2-8: Flush initial apartment creation outbox before requesting invite code.
      let needsOutboxFlush =
        cached?.apartment?.inviteCode == nil
        || (try? SharingStore.hasPendingCreateOperation(apartmentId: apartmentId, in: database))
          == true
      if needsOutboxFlush {
        _ = await syncEngine.processOutbox()
      }

      do {
        let apartment = try await apiClient.getApartment(apartmentId)
        let members = try await apiClient.listApartmentMembers(apartmentId)
        try SharingStore.saveFetchedState(
          apartment: apartment,
          members: members,
          in: database
        )
        await send(.remoteDataLoaded(apartment: apartment, members: members))
      } catch {
        await send(.loadFailed(mapError(error)))
      }
    }
  }

  func handleCopyCode(_ state: inout State) -> Effect<Action> {
    guard let code = state.inviteCode else {
      return .none
    }
    state.showCopiedFeedback = true
    return .run { send in
      await pasteboard.copyString(code)
      await haptics.selection()
      try await clock.sleep(for: .seconds(Self.copyFeedbackDurationSeconds))
      await send(.dismissCopiedFeedback)
    }
    .cancellable(id: CancelID.copyFeedback, cancelInFlight: true)
  }

  func handleResetAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .resetCodeTapped:
      guard state.isOwner, !state.isResettingCode else {
        return .none
      }
      state.isResetConfirmationPresented = true
      return .none

    case .resetConfirmationDismissed:
      state.isResetConfirmationPresented = false
      return .none

    case .resetCodeConfirmed:
      guard state.isOwner, !state.isResettingCode else {
        return .none
      }
      state.isResetConfirmationPresented = false
      state.isResettingCode = true
      state.errorMessage = nil
      let apartmentId = state.apartmentId
      return .run { send in
        do {
          let updated = try await apiClient.resetApartmentInviteCode(apartmentId)
          try SharingStore.saveApartment(updated, in: database)
          await send(.resetCodeSucceeded(updated))
        } catch {
          await send(.resetCodeFailed(mapError(error)))
        }
      }

    case .resetCodeSucceeded(let updated):
      state.isResettingCode = false
      state.apartment = updated
      state.showCopiedFeedback = false
      return .merge(
        .cancel(id: CancelID.copyFeedback),
        .run { _ in
          await haptics.actionSucceeded()
        }
      )

    case .resetCodeFailed(let message):
      state.isResettingCode = false
      state.errorMessage = message
      return .run { _ in
        await haptics.error()
      }

    default:
      return .none
    }
  }

  func mapError(_ error: any Error) -> String {
    L10n.errorMessage(for: error)
  }
}
