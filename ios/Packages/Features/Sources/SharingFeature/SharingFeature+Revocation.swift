import ComposableArchitecture
import Domain
import Foundation

extension SharingFeature {
  func handleRevokeAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .revokeMemberTapped(let member):
      // Decision Q4: Only the Owner can revoke active Contributors; Owner cannot be revoked.
      guard state.isOwner, member.role == .contributor, member.isActive else {
        return .none
      }
      state.pendingRevokeMember = member
      return .none

    case .revokeConfirmationDismissed:
      state.pendingRevokeMember = nil
      return .none

    case .revokeMemberConfirmed:
      return confirmRevoke(&state)

    case .revokeMemberSucceeded(let apartment, let members):
      state.revokingUserId = nil
      if let apartment {
        state.apartment = apartment
      }
      state.members = members
      return .run { _ in
        await haptics.actionSucceeded()
      }

    case .revokeMemberFailed(let message):
      state.revokingUserId = nil
      state.errorMessage = message
      return .run { _ in
        await haptics.error()
      }

    default:
      return .none
    }
  }

  private func confirmRevoke(_ state: inout State) -> Effect<Action> {
    guard
      state.isOwner,
      let member = state.pendingRevokeMember,
      member.role == .contributor,
      member.isActive,
      state.revokingUserId == nil
    else {
      return .none
    }
    state.pendingRevokeMember = nil
    state.revokingUserId = member.userId
    state.errorMessage = nil
    let apartmentId = state.apartmentId
    let currentTime = now
    return .run { send in
      await executeRevoke(
        apartmentId: apartmentId,
        userId: member.userId,
        currentTime: currentTime,
        send: send
      )
    }
  }

  private func executeRevoke(
    apartmentId: String,
    userId: String,
    currentTime: Date,
    send: Send<Action>
  ) async {
    do {
      try await apiClient.revokeApartmentMember(apartmentId, userId)
      try SharingStore.markMemberRevoked(
        apartmentId: apartmentId,
        userId: userId,
        leftAt: currentTime,
        in: database
      )
      if let refreshed = await fetchRemoteSnapshot(apartmentId: apartmentId) {
        try? SharingStore.saveFetchedState(
          apartment: refreshed.apartment,
          members: refreshed.members,
          in: database
        )
        await send(
          .revokeMemberSucceeded(apartment: refreshed.apartment, members: refreshed.members)
        )
        return
      }
      let fallback = try SharingStore.fetchCachedState(apartmentId: apartmentId, from: database)
      await send(.revokeMemberSucceeded(apartment: fallback.apartment, members: fallback.members))
    } catch {
      await send(.revokeMemberFailed(mapError(error)))
    }
  }

  private func fetchRemoteSnapshot(
    apartmentId: String
  ) async -> (apartment: Apartment, members: [ApartmentMember])? {
    guard
      let apartment = try? await apiClient.getApartment(apartmentId),
      let members = try? await apiClient.listApartmentMembers(apartmentId)
    else {
      return nil
    }
    return (apartment: apartment, members: members)
  }
}
