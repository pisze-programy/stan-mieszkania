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
    var selectionHaptics = 0

    func recordOutbox() { outboxCalls += 1 }
    func recordCopied(_ text: String) { copiedStrings.append(text) }
    func recordSelectionHaptic() { selectionHaptics += 1 }
  }

  @MainActor
  @Test("Flushes outbox, filters self from sharedWithMembers, copies with haptic, auto-resets")
  func loadWithOutboxFlushAndCopyAutoReset() async throws {
    let database = try makeInMemoryDatabase()
    try ApartmentMutationStore(database: database).createApartment(
      SharingTestFixtures.pendingApartment,
      creator: SharingTestFixtures.ownerMember,
      outboxId: SharingTestFixtures.outboxId,
      now: SharingTestFixtures.baseDate
    )
    let recorder = Recorder()
    let clock = TestClock()
    let remoteMembers = [SharingTestFixtures.ownerMember, SharingTestFixtures.contributorMember]
    let store = makeLoadTestStore(
      database: database,
      remoteMembers: remoteMembers,
      clock: clock,
      recorder: recorder
    )

    await store.send(.task) { $0.isLoading = true }
    await store.receive(
      .localDataLoaded(
        apartment: SharingTestFixtures.pendingApartment,
        members: [SharingTestFixtures.ownerMember]
      )
    ) {
      $0.apartment = SharingTestFixtures.pendingApartment
      $0.members = [SharingTestFixtures.ownerMember]
    }
    #expect(store.state.sharedWithMembers.isEmpty)

    await store.receive(
      .remoteDataLoaded(apartment: SharingTestFixtures.syncedApartment, members: remoteMembers)
    ) {
      $0.isLoading = false
      $0.apartment = SharingTestFixtures.syncedApartment
      $0.members = remoteMembers
    }
    #expect(store.state.sharedWithMembers == [SharingTestFixtures.contributorMember])
    #expect(store.state.shouldSuggestInviteCodeReset)
    #expect(store.state.shareMessageText?.contains("K7QM-4XPB") == true)

    await store.send(.copyCodeTapped) { $0.showCopiedFeedback = true }
    await clock.advance(by: .seconds(SharingFeature.copyFeedbackDurationSeconds))
    await store.receive(.dismissCopiedFeedback) { $0.showCopiedFeedback = false }

    #expect(await recorder.outboxCalls == 1)
    #expect(await recorder.copiedStrings == ["K7QM-4XPB"])
    #expect(await recorder.selectionHaptics == 1)
  }

  @MainActor
  @Test("Resets invite code immediately without confirmation and auto-hides reset feedback in 2s")
  func resetInviteCodeFlow() async throws {
    let database = try makeInMemoryDatabase()
    let clock = TestClock()
    try SharingStore.saveFetchedState(
      apartment: SharingTestFixtures.syncedApartment,
      members: [SharingTestFixtures.ownerMember],
      in: database
    )

    let store = TestStore(
      initialState: SharingFeature.State(
        apartmentId: SharingTestFixtures.apartmentId,
        currentUserId: SharingTestFixtures.ownerId,
        apartment: SharingTestFixtures.syncedApartment,
        members: [SharingTestFixtures.ownerMember],
        showCopiedFeedback: true
      )
    ) {
      SharingFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.continuousClock = clock
      $0.apiClient.resetApartmentInviteCode = { _ in SharingTestFixtures.resetApartment }
    }

    await store.send(.resetCodeTapped) { $0.isResettingCode = true }
    await store.receive(.resetCodeSucceeded(SharingTestFixtures.resetApartment)) {
      $0.isResettingCode = false
      $0.apartment = SharingTestFixtures.resetApartment
      $0.showCopiedFeedback = false
      $0.showResetFeedback = true
    }
    #expect(!store.state.shouldSuggestInviteCodeReset)

    await clock.advance(by: .seconds(SharingFeature.copyFeedbackDurationSeconds))
    await store.receive(.dismissResetFeedback) { $0.showResetFeedback = false }

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
    clock: TestClock<Duration>,
    recorder: Recorder
  ) -> TestStoreOf<SharingFeature> {
    TestStore(
      initialState: SharingFeature.State(
        apartmentId: SharingTestFixtures.apartmentId,
        currentUserId: SharingTestFixtures.ownerId
      )
    ) {
      SharingFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.continuousClock = clock
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
        selection: { Task { await recorder.recordSelectionHaptic() } },
        markerDropped: {},
        actionSucceeded: {},
        warning: {},
        error: {}
      )
    }
  }
}
