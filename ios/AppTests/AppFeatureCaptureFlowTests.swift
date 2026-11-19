import ApartmentTimelineFeature
import ApartmentsListFeature
import CaptureFeature
import ComposableArchitecture
import Database
import Domain
import Foundation
import MediaStorage
import MediaSummaryFeature
import SharingFeature
import SyncEngine
import Testing

@testable import StanMieszkania

@Suite("AppFeature Capture, Summary, and Sharing Modal Tests")
struct AppFeatureCaptureFlowTests {
  private static let width = 1_200
  private static let height = 900
  private static let bytes = 150_000
  private static let sha256 = String(repeating: "a", count: ContractConstants.sha256HexLength)

  private static let draft = CapturedPhotoDraft(
    id: AppFeatureTests.mediaId,
    apartmentId: AppFeatureTests.apartmentId,
    origin: .photoLibrary,
    source: .imported,
    localFilePath: "/tmp/\(AppFeatureTests.mediaId).jpg",
    sha256: sha256,
    width: width,
    height: height,
    bytes: bytes,
    capturedAt: AppFeatureTests.baseDate,
    capturedTz: "Europe/Warsaw",
    capturedAtFromImport: false,
    location: nil
  )

  @MainActor
  @Test("Sharing delegate and interactive dismiss reload local state without network sync")
  func sharingModalFlow() async throws {
    let store = try makeTimelineStore()
    store.exhaustivity = .off
    let timelineId = try #require(store.state.path.ids.first)
    let shareAction = AppFeature.Action.path(
      .element(
        id: timelineId,
        action: .apartmentTimeline(
          .delegate(.didTapShare(apartmentId: AppFeatureTests.apartmentId)))
      )
    )
    await store.send(shareAction) {
      $0.modal = .sharing(SharingFeature.State(apartmentId: AppFeatureTests.apartmentId))
    }
    await store.send(.modal(.presented(.sharing(.delegate(.didDismiss))))) { $0.modal = nil }
    await store.receive(.apartmentsList(.reloadLocalState))
    await store.receive(
      .path(.element(id: timelineId, action: .apartmentTimeline(.reloadLocalState))))

    await store.send(shareAction)
    await store.send(.modal(.dismiss)) { $0.modal = nil }
    await store.receive(.apartmentsList(.reloadLocalState))
    await store.receive(
      .path(.element(id: timelineId, action: .apartmentTimeline(.reloadLocalState))))
  }

  @MainActor
  @Test("Direct capture enforces re-entrancy, opens summary on finish, and cleans swipe-dismiss")
  func directCaptureReentrancySummaryAndDismissCleanup() async throws {
    let deletedIds = LockIsolated<[String]>([])
    let store = try makeTimelineStore(deletedMediaIds: deletedIds)
    let timelineId = try #require(store.state.path.ids.first)
    let selectLibrary = AppFeature.Action.path(
      .element(
        id: timelineId,
        action: .apartmentTimeline(
          .delegate(
            .didSelectCaptureSource(
              apartmentId: AppFeatureTests.apartmentId,
              source: .photoLibrary
            )
          )
        )
      )
    )
    let expectedCapture = CaptureFeature.State(
      apartmentId: AppFeatureTests.apartmentId,
      source: .photoLibrary
    )
    let expectedSummary = MediaSummaryFeature.State(
      apartmentId: AppFeatureTests.apartmentId,
      drafts: [Self.draft],
      origin: .photoLibrary,
      currentUser: AppFeatureTests.author
    )

    await store.send(selectLibrary) {
      $0.capture = expectedCapture
      $0.path[id: timelineId, case: \.apartmentTimeline]?.isCaptureInProgress = true
    }
    await store.receive(.capture(.start)) {
      $0.capture?.isPickerPresented = true
    }

    await store.send(selectLibrary)
    #expect(store.state.modal == nil)

    await store.send(
      .capture(.delegate(.didFinishCapture([Self.draft], origin: .photoLibrary)))
    ) {
      $0.capture = nil
      $0.path[id: timelineId, case: \.apartmentTimeline]?.isCaptureInProgress = false
      $0.modal = .mediaSummary(expectedSummary)
    }
    await store.send(.modal(.dismiss)) { $0.modal = nil }
    #expect(deletedIds.value == [Self.draft.id])
  }

  @MainActor
  @Test("Popping timeline clears active capture and didCancel unlocks timeline menu")
  func popTimelineAndCancelClearCaptureState() async throws {
    let store = try makeTimelineStore()
    let timelineId = try #require(store.state.path.ids.first)
    let selectFiles = AppFeature.Action.path(
      .element(
        id: timelineId,
        action: .apartmentTimeline(
          .delegate(
            .didSelectCaptureSource(apartmentId: AppFeatureTests.apartmentId, source: .files)
          )
        )
      )
    )

    await store.send(selectFiles) {
      $0.capture = CaptureFeature.State(apartmentId: AppFeatureTests.apartmentId, source: .files)
      $0.path[id: timelineId, case: \.apartmentTimeline]?.isCaptureInProgress = true
    }
    await store.receive(.capture(.start)) { $0.capture?.isPickerPresented = true }
    await store.send(.capture(.delegate(.didCancel))) {
      $0.capture = nil
      $0.path[id: timelineId, case: \.apartmentTimeline]?.isCaptureInProgress = false
    }

    await store.send(selectFiles) {
      $0.capture = CaptureFeature.State(apartmentId: AppFeatureTests.apartmentId, source: .files)
      $0.path[id: timelineId, case: \.apartmentTimeline]?.isCaptureInProgress = true
    }
    await store.receive(.capture(.start)) { $0.capture?.isPickerPresented = true }
    await store.send(.path(.popFrom(id: timelineId))) {
      $0.capture = nil
      $0.path.pop(from: timelineId)
    }
  }

  @MainActor
  private func makeTimelineStore(
    deletedMediaIds: LockIsolated<[String]> = LockIsolated([])
  ) throws -> TestStoreOf<AppFeature> {
    let database = try makeInMemoryDatabase()
    var initial = AppFeature.State(
      isBootstrapping: false,
      isAuthenticated: true,
      currentUser: AppFeatureTests.profile,
      apartmentsList: ApartmentsListFeature.State(currentUser: AppFeatureTests.profile)
    )
    let apartment = Apartment(
      id: AppFeatureTests.apartmentId,
      ownerId: AppFeatureTests.userId,
      name: "Kawalerka Mokotów",
      street: "Puławska 10",
      city: "Warszawa",
      role: .owner,
      createdAt: AppFeatureTests.baseDate,
      updatedAt: AppFeatureTests.baseDate
    )
    initial.path.append(
      .apartmentTimeline(
        ApartmentTimelineFeature.State(
          apartmentId: AppFeatureTests.apartmentId,
          apartment: apartment
        )
      )
    )
    return TestStore(initialState: initial) {
      AppFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.calendar = Calendar(identifier: .gregorian)
      $0.timeZone = .gmt
      $0.syncEngine.events = { AsyncStream { $0.finish() } }
      $0.mediaStorage.deleteLocalFile = { mediaId in
        deletedMediaIds.withValue { $0.append(mediaId) }
      }
    }
  }
}
