import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import SQLiteData
import Synchronization
import Testing

@testable import ApartmentTimelineFeature

@Suite("ApartmentTimelineFeature Leave, Delete, and Delegate Tests")
struct TimelineLeaveAndDelegatesTests {
  private actor LeaveRecorder {
    var deletedOrLeftOwnerIds: [String] = []
    var leftContributorIds: [String] = []

    func recordOwnerDelete(_ id: String) { deletedOrLeftOwnerIds.append(id) }
    func recordContributorLeave(_ id: String) { leftContributorIds.append(id) }
  }

  @MainActor
  @Test(
    "Owner delete/leave calls deleteOrLeaveApartment, clears local cache + JPEGs, emits delegate")
  func ownerDeleteOrLeaveApartment() async throws {
    let database = try TimelineTestFixtures.seedTimelineDatabase(role: .owner)
    let recorder = LeaveRecorder()
    let successHaptics = Mutex<Int>(0)
    let deletedFiles = LockIsolated<[String]>([])
    let store = TestStore(
      initialState: ApartmentTimelineFeature.State(
        apartmentId: TimelineTestFixtures.apartmentId,
        apartment: TimelineTestFixtures.makeApartment(role: .owner)
      )
    ) {
      ApartmentTimelineFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.apiClient.deleteOrLeaveApartment = { id in await recorder.recordOwnerDelete(id) }
      $0.mediaStorage.deleteLocalFile = { id in deletedFiles.withValue { $0.append(id) } }
      $0.haptics.actionSucceeded = { successHaptics.withLock { $0 += 1 } }
    }

    await store.send(.leaveOrDeleteMenuTapped) {
      $0.leaveConfirmationMode = .ownerDeleteOrLeave
    }
    await store.send(.leaveOrDeleteConfirmed) { $0.isLeavingOrDeleting = true }
    await store.receive(.leaveOrDeleteSucceeded) {
      $0.isLeavingOrDeleting = false
      $0.leaveConfirmationMode = nil
    }
    await store.receive(\.delegate.didLeaveOrDeleteApartment)

    #expect(await recorder.deletedOrLeftOwnerIds == [TimelineTestFixtures.apartmentId])
    #expect(successHaptics.withLock { $0 } == 1)
    #expect(
      Set(deletedFiles.value) == [
        TimelineTestFixtures.mediaLocalId,
        TimelineTestFixtures.mediaVerifiedId,
        TimelineTestFixtures.mediaTombstoneId,
      ]
    )
    let remaining = try await database.read { db in
      try ApartmentRecord.where { $0.id.eq(TimelineTestFixtures.apartmentId) }.fetchOne(db)
    }
    #expect(remaining == nil)
  }

  @MainActor
  @Test("Contributor leave calls leaveApartment, clears local cache + JPEGs, and emits delegate")
  func contributorLeaveApartment() async throws {
    let database = try TimelineTestFixtures.seedTimelineDatabase(role: .contributor)
    let recorder = LeaveRecorder()
    let successHaptics = Mutex<Int>(0)
    let deletedFiles = LockIsolated<[String]>([])
    let store = TestStore(
      initialState: ApartmentTimelineFeature.State(
        apartmentId: TimelineTestFixtures.apartmentId,
        apartment: TimelineTestFixtures.makeApartment(role: .contributor)
      )
    ) {
      ApartmentTimelineFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.apiClient.leaveApartment = { id in await recorder.recordContributorLeave(id) }
      $0.mediaStorage.deleteLocalFile = { id in deletedFiles.withValue { $0.append(id) } }
      $0.haptics.actionSucceeded = { successHaptics.withLock { $0 += 1 } }
    }

    await store.send(.leaveOrDeleteMenuTapped) {
      $0.leaveConfirmationMode = .contributorLeave
    }
    await store.send(.leaveOrDeleteConfirmed) { $0.isLeavingOrDeleting = true }
    await store.receive(.leaveOrDeleteSucceeded) {
      $0.isLeavingOrDeleting = false
      $0.leaveConfirmationMode = nil
    }
    await store.receive(\.delegate.didLeaveOrDeleteApartment)

    #expect(await recorder.leftContributorIds == [TimelineTestFixtures.apartmentId])
    #expect(successHaptics.withLock { $0 } == 1)
    #expect(
      Set(deletedFiles.value) == [
        TimelineTestFixtures.mediaLocalId,
        TimelineTestFixtures.mediaVerifiedId,
        TimelineTestFixtures.mediaTombstoneId,
      ]
    )
  }

  @MainActor
  @Test("Capture source sheet emits camera, photo library, and files delegates")
  func captureSourceDelegates() async {
    let store = TestStore(
      initialState: ApartmentTimelineFeature.State(
        apartmentId: TimelineTestFixtures.apartmentId,
        apartment: TimelineTestFixtures.makeApartment(role: .owner)
      )
    ) {
      ApartmentTimelineFeature()
    }

    await store.send(.captureButtonTapped) { $0.isCaptureSourceSheetPresented = true }
    await store.send(.captureSourceSelected(.camera)) { $0.isCaptureSourceSheetPresented = false }
    await store.receive(
      .delegate(
        .didSelectCaptureSource(apartmentId: TimelineTestFixtures.apartmentId, source: .camera)
      )
    )
    await store.send(.captureSourceSelected(.photoLibrary))
    await store.receive(
      .delegate(
        .didSelectCaptureSource(
          apartmentId: TimelineTestFixtures.apartmentId,
          source: .photoLibrary
        )
      )
    )
    await store.send(.captureSourceSelected(.files))
    await store.receive(
      .delegate(
        .didSelectCaptureSource(apartmentId: TimelineTestFixtures.apartmentId, source: .files)
      )
    )
    #expect(L10n.string("apartment.timeline.capture.video") == "Wideo")
    #expect(L10n.string("apartment.timeline.capture.video.disabled") == "Dostępne wkrótce")
  }

  @MainActor
  @Test("Share and Media selection emit delegates and views instantiate cleanly")
  func shareMediaDelegatesAndViews() async {
    let ownerStore = TestStore(
      initialState: ApartmentTimelineFeature.State(
        apartmentId: TimelineTestFixtures.apartmentId,
        apartment: TimelineTestFixtures.makeApartment(
          role: .owner,
          shouldSuggestInviteCodeReset: true
        )
      )
    ) {
      ApartmentTimelineFeature()
    }
    #expect(ownerStore.state.shouldHighlightShare)
    await ownerStore.send(.shareTapped)
    await ownerStore.receive(.delegate(.didTapShare(apartmentId: TimelineTestFixtures.apartmentId)))
    await ownerStore.send(.mediaTapped(TimelineTestFixtures.mediaVerifiedId))
    await ownerStore.receive(
      .delegate(.didSelectMedia(mediaId: TimelineTestFixtures.mediaVerifiedId))
    )

    let contributorStore = TestStore(
      initialState: ApartmentTimelineFeature.State(
        apartmentId: TimelineTestFixtures.apartmentId,
        apartment: TimelineTestFixtures.makeApartment(
          role: .contributor,
          shouldSuggestInviteCodeReset: true
        )
      )
    ) {
      ApartmentTimelineFeature()
    }
    #expect(!contributorStore.state.shouldHighlightShare)
    await contributorStore.send(.shareTapped)

    let viewStore = Store(
      initialState: ApartmentTimelineFeature.State(
        apartmentId: TimelineTestFixtures.apartmentId,
        apartment: TimelineTestFixtures.makeApartment(role: .owner)
      )
    ) {
      ApartmentTimelineFeature()
    }
    _ = (
      ApartmentTimelineView(store: viewStore),
      CaptureSourceSheetView(onSelect: { _ in }, onCancel: {}),
      ApartmentHistorySheetView(sheet: ApartmentHistorySheetState(), onClose: {}),
      TimelineDayHeaderView(title: "17 listopada, czwartek"),
    )
  }
}
