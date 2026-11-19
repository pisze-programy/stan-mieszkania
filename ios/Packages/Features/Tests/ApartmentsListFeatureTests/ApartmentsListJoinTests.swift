import APIClient
import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import Testing

@testable import ApartmentsListFeature

@Suite("ApartmentsListFeature Join Tests")
struct ApartmentsListJoinTests {
  private enum Fixtures {
    static let userId = "01933e2a-7b40-7000-8000-000000000001"
    static let joinedApartmentId = "01933e2a-7b40-7000-8000-000000000010"
    static let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
    static let rateLimitedStatus = 429

    static let user = UserProfile(
      id: userId,
      displayName: "Jan Kowalski",
      shortTag: "A1B2",
      color: DomainConstants.defaultAuthorColor,
      createdAt: baseDate
    )

    static let joinedApartment = Apartment(
      id: joinedApartmentId,
      ownerId: "01933e2a-7b40-7000-8000-000000000099",
      name: "Mieszkanie Wola",
      street: "Kasprzaka 5",
      city: "Warszawa",
      role: .contributor,
      createdAt: baseDate,
      updatedAt: baseDate
    )
  }

  private actor JoinRecorder {
    var syncedApartmentIds: [String] = []
    var submittedCodes: [String] = []

    func recordSyncApartment(_ id: String) { syncedApartmentIds.append(id) }
    func recordJoinCode(_ code: String) { submittedCodes.append(code) }
  }

  @MainActor
  @Test("Formats invite code, rejects invalid alphabet, and surfaces 429 rate limit")
  func joinApartmentValidationAndRateLimit() async throws {
    let database = try makeInMemoryDatabase()
    try ApartmentMutationStore(database: database).saveLocalUser(Fixtures.user)
    let rateLimitProblem = APIProblemError(
      status: Fixtures.rateLimitedStatus,
      code: .known(.inviteCodeRateLimited),
      title: "Too Many Requests",
      detail: "Rate limited"
    )

    let store = TestStore(initialState: ApartmentsListFeature.State()) {
      ApartmentsListFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.date.now = Fixtures.baseDate
      $0.apiClient.joinApartmentByCode = { _ in
        throw rateLimitProblem
      }
    }

    await store.send(.joinMenuTapped) {
      $0.joinSheet = ApartmentsListFeature.JoinApartmentSheetState()
    }
    await store.send(.joinCodeChanged("k7qm0xpb")) {
      $0.joinSheet?.inviteCode = "K7QM-0XPB"
    }
    await store.send(.joinSubmitted) {
      $0.joinSheet?.errorMessage = L10n.errorMessage(for: .inviteCodeInvalid)
    }

    await store.send(.joinCodeChanged("k7qm4xpb")) {
      $0.joinSheet?.inviteCode = "K7QM-4XPB"
      $0.joinSheet?.errorMessage = nil
    }
    await store.send(.joinSubmitted) {
      $0.joinSheet?.isJoining = true
    }
    let expectedMessage = L10n.errorMessage(for: .inviteCodeRateLimited)
    await store.receive(.joinFailed(expectedMessage)) {
      $0.joinSheet?.isJoining = false
      $0.joinSheet?.errorMessage = expectedMessage
    }
  }

  @MainActor
  @Test("Joins apartment by valid invite code, persists locally, syncs, and emits delegate")
  func joinApartmentSuccess() async throws {
    let database = try makeInMemoryDatabase()
    try ApartmentMutationStore(database: database).saveLocalUser(Fixtures.user)
    let recorder = JoinRecorder()

    let store = TestStore(initialState: ApartmentsListFeature.State()) {
      ApartmentsListFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.date.now = Fixtures.baseDate
      $0.apiClient.joinApartmentByCode = { code in
        await recorder.recordJoinCode(code)
        return Fixtures.joinedApartment
      }
      $0.syncEngine.syncApartment = { id in
        await recorder.recordSyncApartment(id)
        return 0
      }
    }

    await store.send(.joinMenuTapped) {
      $0.joinSheet = ApartmentsListFeature.JoinApartmentSheetState()
    }
    await store.send(.joinCodeChanged("k7qm4xpb")) {
      $0.joinSheet?.inviteCode = "K7QM-4XPB"
    }
    await store.send(.joinSubmitted) {
      $0.joinSheet?.isJoining = true
    }

    let expectedItems = [ApartmentListItem(apartment: Fixtures.joinedApartment, photoCount: 0)]
    await store.receive(
      .joinSucceeded(
        apartmentId: Fixtures.joinedApartmentId,
        user: Fixtures.user,
        items: expectedItems
      )
    ) {
      $0.joinSheet = nil
      $0.currentUser = Fixtures.user
      $0.items = expectedItems
    }
    await store.receive(\.delegate.didSelectApartment)

    #expect(await recorder.submittedCodes == ["K7QM-4XPB"])
    #expect(await recorder.syncedApartmentIds == [Fixtures.joinedApartmentId])
  }
}
