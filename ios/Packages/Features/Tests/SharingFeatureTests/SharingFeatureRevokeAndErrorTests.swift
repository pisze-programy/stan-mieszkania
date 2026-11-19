import APIClient
import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import Testing

@testable import SharingFeature

@Suite("SharingFeature Revocation and Error Tests")
struct SharingFeatureRevokeAndErrorTests {
  private actor RevokeRecorder {
    var revokedPairs: [(String, String)] = []
    var errorHaptics = 0

    func recordRevoke(apartmentId: String, userId: String) {
      revokedPairs.append((apartmentId, userId))
    }
    func recordErrorHaptic() { errorHaptics += 1 }
  }

  @MainActor
  @Test("Owner revokes active Contributor while ignoring Owner revocation and preserving history")
  func revokeContributorAccess() async throws {
    let database = try makeInMemoryDatabase()
    try SharingStore.saveFetchedState(
      apartment: SharingTestFixtures.resetApartment,
      members: [SharingTestFixtures.ownerMember, SharingTestFixtures.contributorMember],
      in: database
    )
    let recorder = RevokeRecorder()
    let updatedMembers = [SharingTestFixtures.ownerMember, SharingTestFixtures.revokedContributor]

    let store = TestStore(
      initialState: SharingFeature.State(
        apartmentId: SharingTestFixtures.apartmentId,
        apartment: SharingTestFixtures.resetApartment,
        members: [SharingTestFixtures.ownerMember, SharingTestFixtures.contributorMember]
      )
    ) {
      SharingFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.date.now = SharingTestFixtures.revokeDate
      $0.apiClient.revokeApartmentMember = { apartmentId, userId in
        await recorder.recordRevoke(apartmentId: apartmentId, userId: userId)
      }
      $0.apiClient.getApartment = { _ in SharingTestFixtures.resetApartment }
      $0.apiClient.listApartmentMembers = { _ in updatedMembers }
    }

    await store.send(.revokeMemberTapped(SharingTestFixtures.ownerMember))
    await store.send(.revokeMemberTapped(SharingTestFixtures.contributorMember)) {
      $0.pendingRevokeMember = SharingTestFixtures.contributorMember
    }
    await store.send(.revokeMemberConfirmed) {
      $0.pendingRevokeMember = nil
      $0.revokingUserId = SharingTestFixtures.contributorId
    }
    await store.receive(
      .revokeMemberSucceeded(apartment: SharingTestFixtures.resetApartment, members: updatedMembers)
    ) {
      $0.revokingUserId = nil
      $0.members = updatedMembers
    }

    #expect(store.state.activeMembers == [SharingTestFixtures.ownerMember])
    #expect(store.state.departedMembers == [SharingTestFixtures.revokedContributor])
    let pairs = await recorder.revokedPairs
    #expect(pairs.count == 1)
    #expect(pairs.first?.0 == SharingTestFixtures.apartmentId)
    #expect(pairs.first?.1 == SharingTestFixtures.contributorId)
  }

  @MainActor
  @Test("Maps APIProblemError to localized Polish message and triggers error haptic")
  func apiProblemFailure() async throws {
    let database = try makeInMemoryDatabase()
    let recorder = RevokeRecorder()
    let problem = APIProblemError(
      status: SharingTestFixtures.forbiddenStatus,
      code: .known(.apartmentOwnerRequired),
      title: "Forbidden",
      detail: "Owner required"
    )

    let store = TestStore(
      initialState: SharingFeature.State(
        apartmentId: SharingTestFixtures.apartmentId,
        apartment: SharingTestFixtures.resetApartment,
        members: [SharingTestFixtures.ownerMember, SharingTestFixtures.contributorMember]
      )
    ) {
      SharingFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.apiClient.resetApartmentInviteCode = { _ in throw problem }
      $0.haptics = HapticsClient(
        markerDropped: {},
        actionSucceeded: {},
        warning: {},
        error: { Task { await recorder.recordErrorHaptic() } }
      )
    }

    await store.send(.resetCodeTapped) {
      $0.isResettingCode = true
    }
    let expectedError = L10n.errorMessage(for: .apartmentOwnerRequired)
    await store.receive(.resetCodeFailed(expectedError)) {
      $0.isResettingCode = false
      $0.errorMessage = expectedError
    }
    await store.send(.dismissError) {
      $0.errorMessage = nil
    }
    #expect(await recorder.errorHaptics == 1)
  }

  @MainActor
  @Test("Instantiates SharingView cleanly")
  func instantiatesViews() {
    let viewStore = Store(
      initialState: SharingFeature.State(
        apartmentId: SharingTestFixtures.apartmentId,
        apartment: SharingTestFixtures.syncedApartment,
        members: [SharingTestFixtures.ownerMember, SharingTestFixtures.revokedContributor]
      )
    ) {
      SharingFeature()
    }
    let sharingView = SharingView(store: viewStore)
    _ = sharingView
  }
}
