import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation

extension ApartmentTimelineFeature {
  func handleManagementAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .editMenuTapped, .editSheetDismissed, .editNameChanged, .editStreetChanged,
      .editCityChanged, .editSubmitted, .editSucceeded, .editFailed:
      return handleEditAction(&state, action: action)
    case .historyMenuTapped, .historySheetDismissed, .historyLoaded, .historyFailed:
      return handleHistoryAction(&state, action: action)
    case .leaveOrDeleteMenuTapped, .leaveConfirmationDismissed, .leaveConfirmationDidDismiss,
      .leaveOrDeleteConfirmed, .leaveOrDeleteSucceeded, .leaveOrDeleteFailed:
      return handleLeaveOrDeleteAction(&state, action: action)
    default:
      return .none
    }
  }

  private func handleHistoryAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .historyMenuTapped:
      state.now = now
      let local = try? ApartmentTimelineStore.fetchLocalHistory(
        apartmentId: state.apartmentId,
        from: database
      )
      state.historySheet = ApartmentHistorySheetState(
        changes: local?.changes ?? [],
        authorNames: local?.authorNames ?? [:],
        isLoading: true
      )
      let apartmentId = state.apartmentId
      return .run { send in
        do {
          let remoteChanges = try await apiClient.listApartmentHistory(apartmentId)
          let store = ApartmentMutationStore(database: database)
          try store.upsertApartmentChanges(remoteChanges)
          let refreshed = try ApartmentTimelineStore.fetchLocalHistory(
            apartmentId: apartmentId,
            from: database
          )
          await send(
            .historyLoaded(changes: refreshed.changes, authorNames: refreshed.authorNames)
          )
        } catch {
          await send(.historyFailed(mapError(error)))
        }
      }
    case .historySheetDismissed:
      state.historySheet = nil
      return .none
    case .historyLoaded(let changes, let authorNames):
      state.historySheet?.changes = changes
      state.historySheet?.authorNames = authorNames
      state.historySheet?.isLoading = false
      state.historySheet?.errorMessage = nil
      return .none
    case .historyFailed(let message):
      state.historySheet?.isLoading = false
      if state.historySheet?.changes.isEmpty == true {
        state.historySheet?.errorMessage = message
      }
      return .none
    default:
      return .none
    }
  }

  private func handleLeaveOrDeleteAction(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .leaveOrDeleteMenuTapped:
      state.leaveConfirmationMode = state.isOwner ? .ownerDeleteOrLeave : .contributorLeave
      return .none
    case .leaveConfirmationDismissed:
      guard !state.isLeavingOrDeleting else {
        return .none
      }
      state.leaveConfirmationMode = nil
      return .none
    case .leaveConfirmationDidDismiss:
      guard state.pendingLeaveOrDeleteSuccess else {
        return .none
      }
      state.pendingLeaveOrDeleteSuccess = false
      return .merge(
        .cancel(id: CancelID.sync),
        .cancel(id: CancelID.syncEvents),
        .cancel(id: CancelID.quotaNoticeDismiss),
        .run { _ in
          await haptics.actionSucceeded()
        },
        .send(.delegate(.didLeaveOrDeleteApartment))
      )
    case .leaveOrDeleteConfirmed:
      return confirmLeaveOrDelete(&state)
    case .leaveOrDeleteSucceeded:
      state.isLeavingOrDeleting = false
      state.pendingLeaveOrDeleteSuccess = true
      state.leaveConfirmationMode = nil
      return .none
    case .leaveOrDeleteFailed(let message):
      state.isLeavingOrDeleting = false
      state.pendingLeaveOrDeleteSuccess = false
      state.leaveConfirmationMode = nil
      state.errorMessage = message
      return .run { _ in
        await haptics.error()
      }
    default:
      return .none
    }
  }

  private func confirmLeaveOrDelete(_ state: inout State) -> Effect<Action> {
    guard let mode = state.leaveConfirmationMode, !state.isLeavingOrDeleting else {
      return .none
    }
    state.isLeavingOrDeleting = true
    state.errorMessage = nil
    let apartmentId = state.apartmentId
    return .run { send in
      do {
        switch mode {
        case .ownerDeleteOrLeave:
          try await apiClient.deleteOrLeaveApartment(apartmentId)
        case .contributorLeave:
          try await apiClient.leaveApartment(apartmentId)
        }
        let deletedMediaIds = try ApartmentTimelineStore.removeLocalApartment(
          apartmentId: apartmentId,
          from: database
        )
        for mediaId in deletedMediaIds {
          try? mediaStorage.deleteLocalFile(mediaId)
        }
        await send(.leaveOrDeleteSucceeded)
      } catch {
        await send(.leaveOrDeleteFailed(mapError(error)))
      }
    }
  }
}

extension ApartmentTimelineFeature.State {
  public var leaveOrDeleteMenuTitle: String {
    if isOwner && !hasOtherMembers {
      return L10n.string("apartment.menu.delete")
    }
    return L10n.string("apartment.menu.leave")
  }

  public var leaveOrDeleteMenuIcon: String {
    isOwner && !hasOtherMembers ? "trash" : "rectangle.portrait.and.arrow.right"
  }

  public var leaveOrDeleteConfirmationContent: ConfirmationSheetContent {
    switch leaveConfirmationMode {
    case .ownerDeleteOrLeave where !hasOtherMembers:
      return ConfirmationSheetContent(
        systemImage: "trash",
        title: L10n.string("apartment.delete.confirmation.title"),
        message: L10n.format("apartment.delete.sheet.message", navigationTitle),
        confirmTitle: L10n.string("apartment.delete.confirm.full"),
        tone: .destructive
      )
    case .ownerDeleteOrLeave:
      return ConfirmationSheetContent(
        systemImage: "rectangle.portrait.and.arrow.right",
        title: L10n.string("apartment.leave.confirmation.title"),
        message: L10n.string("apartment.leave.owner.message"),
        confirmTitle: L10n.string("apartment.leave.confirm.full"),
        tone: .destructive
      )
    case .contributorLeave, .none:
      return ConfirmationSheetContent(
        systemImage: "rectangle.portrait.and.arrow.right",
        title: L10n.string("apartment.leave.confirmation.title"),
        message: L10n.string("apartment.leave.confirmation.message"),
        confirmTitle: L10n.string("apartment.leave.confirm.full"),
        tone: .destructive
      )
    }
  }
}
