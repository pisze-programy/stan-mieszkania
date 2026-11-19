import ComposableArchitecture
import DesignSystem
import Domain
import Foundation

extension ApartmentsListFeature {
  func handleJoinAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .joinMenuTapped:
      state.joinSheet = JoinApartmentSheetState()
      return .none
    case .joinSheetDismissed:
      state.joinSheet = nil
      return .none
    case .joinCodeChanged(let raw):
      state.joinSheet?.inviteCode = InviteCodeFormatter.formatInput(raw)
      state.joinSheet?.errorMessage = nil
      return .none
    case .joinSubmitted:
      return submitJoin(&state)
    case .joinSucceeded(let apartmentId, let user, let items):
      state.joinSheet = nil
      state.currentUser = user
      state.items = items
      let selectEffect: Effect<Action> =
        if let item = items.first(where: { $0.id == apartmentId }) {
          .send(.delegate(.didSelectApartment(item)))
        } else {
          .none
        }
      return .merge(
        .run { _ in
          await haptics.actionSucceeded()
        },
        selectEffect
      )
    case .joinFailed(let message):
      state.joinSheet?.isJoining = false
      state.joinSheet?.errorMessage = message
      return .run { _ in
        await haptics.error()
      }
    default:
      return .none
    }
  }

  private func submitJoin(_ state: inout State) -> Effect<Action> {
    guard let sheet = state.joinSheet, !sheet.isJoining else {
      return .none
    }
    guard let normalizedCode = InviteCodeFormatter.validate(sheet.inviteCode) else {
      state.joinSheet?.errorMessage = L10n.errorMessage(for: .inviteCodeInvalid)
      return .run { _ in
        await haptics.warning()
      }
    }
    state.joinSheet?.isJoining = true
    state.joinSheet?.errorMessage = nil
    let currentTime = now
    return .run { send in
      do {
        let apartment = try await apiClient.joinApartmentByCode(normalizedCode)
        try ApartmentsListStore.saveJoinedApartment(apartment, in: database, now: currentTime)
        _ = try? await syncEngine.syncApartment(apartmentId: apartment.id)
        let snapshot = try ApartmentsListStore.fetchSnapshot(from: database)
        await send(
          .joinSucceeded(
            apartmentId: apartment.id,
            user: snapshot.user,
            items: snapshot.items
          )
        )
      } catch {
        await send(.joinFailed(mapError(error)))
      }
    }
  }
}

extension ApartmentsListFeature.CreateApartmentSheetState {
  public var isValid: Bool {
    if case .success = ApartmentsListStore.validateCreateInput(
      name: name,
      street: street,
      city: city
    ) {
      return true
    }
    return false
  }

  public var hasUnsavedInput: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

extension ApartmentsListFeature.JoinApartmentSheetState {
  public var isCodeValid: Bool {
    InviteCodeFormatter.validate(inviteCode) != nil
  }

  public var hasUnsavedInput: Bool {
    !inviteCode.isEmpty
  }
}
