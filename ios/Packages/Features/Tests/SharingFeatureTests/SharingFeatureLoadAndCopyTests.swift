import APIClient
import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import SQLiteData
import SyncEngine
import Testing

@testable import SharingFeature

@Suite("SharingFeature Load, Copy, and Reset Tests")
struct SharingFeatureLoadAndCopyTests {
  private actor Recorder {
    var outboxCalls = 0
    var copiedStrings: [String] = []
    var successHaptics = 0

    func recordOutbox() { outboxCalls += 1 }
    func recordCopied(_ text: String) { copiedStrings.append(text) }
    func recordSuccessHaptic() { successHaptics += 1 }
  }

  @MainActor
  @Test("Flushes pending outbox, loads invite code with security banner, and copies code")
  func loadWithOutboxFlushAndCopy() async throws {
    let database = try makeInMemoryDatabase()
    try ApartmentMutationStore(database: database).createApartment(
      SharingTestFixtures.pendingApartment,
      creator: SharingTestFixtures.ownerMember,
      outboxId: SharingTestFixtures.outboxId,
      now: SharingTestFixtures.baseDate
    )
    let recorder = Recorder()
    let remoteMembers = [SharingTestFixtures.ownerMember, SharingTestFixtures.contributorMember]
    let store = makeLoadTestStore(
      database: database,
      remoteMembers: remoteMembers,
      recorder: recorder
    )

    await store.send(.task) {
      $0.isLoading = true
    }
    await store.receive(
      .localDataLoaded(
        apartment: SharingTestFixtures.pendingApartment,
        members: [SharingTestFixtures.ownerMember]
      )
    ) {
      $0.apartment = SharingTestFixtures.pendingApartment
      $0.members = [SharingTestFixtures.ownerMember]
    }
    await store.receive(
      .remoteDataLoaded(apartment: SharingTestFixtures.syncedApartment, members: remoteMembers)
    ) {
      $0.isLoading = false
      $0.apartment = SharingTestFixtures.syncedApartment
      $0.members = remoteMembers
    }
    #expect(store.state.shouldSuggestInviteCodeReset)
    #expect(store.state.shareMessageText?.contains("K7QM-4XPB") == true)

    await store.send(.copyCodeTapped) {
      $0.showCopiedFeedback = true
    }
    #expect(await recorder.outboxCalls == 1)
    #expect(await recorder.copiedStrings == ["K7QM-4XPB"])
    #expect(await recorder.successHaptics == 1)
  }

  @MainActor
  @Test("Resets invite code after confirmation and clears reset suggestion banner")
  func resetInviteCodeFlow() async throws {
    let database = try makeInMemoryDatabase()
    try SharingStore.saveFetchedState(
      apartment: SharingTestFixtures.syncedApartment,
      members: [SharingTestFixtures.ownerMember],
      in: database
    )

    let store = TestStore(
      initialState: SharingFeature.State(
        apartmentId: SharingTestFixtures.apartmentId,
        apartment: SharingTestFixtures.syncedApartment,
        members: [SharingTestFixtures.ownerMember],
        showCopiedFeedback: true
      )
    ) {
      SharingFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.apiClient.resetApartmentInviteCode = { _ in SharingTestFixtures.resetApartment }
    }

    await store.send(.resetCodeTapped) {
      $0.isResetConfirmationPresented = true
    }
    await store.send(.resetCodeConfirmed) {
      $0.isResetConfirmationPresented = false
      $0.isResettingCode = true
    }
    await store.receive(.resetCodeSucceeded(SharingTestFixtures.resetApartment)) {
      $0.isResettingCode = false
      $0.apartment = SharingTestFixtures.resetApartment
      $0.showCopiedFeedback = false
    }
    #expect(!store.state.shouldSuggestInviteCodeReset)

    let cached = try SharingStore.fetchCachedState(
      apartmentId: SharingTestFixtures.apartmentId,
      from: database
    )
    #expect(cached.apartment?.inviteCode == "M9TR-7WXZ")
  }

  @MainActor
  @Test("Close toolbar button emits delegate didDismiss")
  func closeTappedEmitsDidDismissDelegate() async {
    let store = TestStore(
      initialState: SharingFeature.State(apartmentId: SharingTestFixtures.apartmentId)
    ) {
      SharingFeature()
    }

    await store.send(.closeTapped)
    await store.receive(\.delegate.didDismiss)
  }

  @MainActor
  private func makeLoadTestStore(
    database: any DatabaseWriter,
    remoteMembers: [ApartmentMember],
    recorder: Recorder
  ) -> TestStoreOf<SharingFeature> {
    TestStore(initialState: SharingFeature.State(apartmentId: SharingTestFixtures.apartmentId)) {
      SharingFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.syncEngine.processOutbox = {
        await recorder.recordOutbox()
        return SyncOutboxReport(
          processedCount: 1,
          failedCount: 0,
          deferredCount: 0,
          pausedForForceUpdate: false
        )
      }
      $0.apiClient.getApartment = { _ in SharingTestFixtures.syncedApartment }
      $0.apiClient.listApartmentMembers = { _ in remoteMembers }
      $0.pasteboard.copyString = { text in Task { await recorder.recordCopied(text) } }
      $0.haptics = HapticsClient(
        markerDropped: {},
        actionSucceeded: { Task { await recorder.recordSuccessHaptic() } },
        warning: {},
        error: {}
      )
    }
  }
}
