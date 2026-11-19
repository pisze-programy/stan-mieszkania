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
    origin: .camera,
    source: .camera,
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
  @Test("Interactive swipe-dismiss of MediaSummary deletes unsaved draft JPEGs on disk")
  func interactiveSummaryDismissCleansUpDraftFiles() async throws {
    let deletedIds = LockIsolated<[String]>([])
    let store = try makeTimelineStore(deletedMediaIds: deletedIds)
    let expectedSummary = MediaSummaryFeature.State(
      apartmentId: AppFeatureTests.apartmentId,
      drafts: [Self.draft],
      origin: .camera,
      currentUser: AppFeatureTests.author
    )
    let timelineId = try #require(store.state.path.ids.first)
    await store.send(
      .path(
        .element(
          id: timelineId,
          action: .apartmentTimeline(
            .delegate(
              .didSelectCaptureSource(apartmentId: AppFeatureTests.apartmentId, source: .camera)
            )
          )
        )
      )
    ) {
      $0.modal = .capture(
        CaptureFeature.State(apartmentId: AppFeatureTests.apartmentId, source: .camera)
      )
    }
    await store.send(
      .modal(.presented(.capture(.delegate(.didFinishCapture([Self.draft], origin: .camera)))))
    ) {
      $0.modal = .mediaSummary(expectedSummary)
    }
    await store.send(.modal(.dismiss)) {
      $0.modal = nil
    }
    #expect(deletedIds.value == [Self.draft.id])
  }

  @MainActor
  @Test("Routes Capture -> Summary -> Retake -> CaptureAnother and reloads local state")
  func captureSummaryRetakeLoopFlow() async throws {
    let store = try makeTimelineStore()
    store.exhaustivity = .off
    let timelineId = try #require(store.state.path.ids.first)
    let expectedCapture = CaptureFeature.State(
      apartmentId: AppFeatureTests.apartmentId,
      source: .camera
    )
    let expectedSummary = MediaSummaryFeature.State(
      apartmentId: AppFeatureTests.apartmentId,
      drafts: [Self.draft],
      origin: .camera,
      currentUser: AppFeatureTests.author
    )

    await store.send(
      .path(
        .element(
          id: timelineId,
          action: .apartmentTimeline(
            .delegate(
              .didSelectCaptureSource(apartmentId: AppFeatureTests.apartmentId, source: .camera)
            )
          )
        )
      )
    ) { $0.modal = .capture(expectedCapture) }
    await store.send(
      .modal(.presented(.capture(.delegate(.didFinishCapture([Self.draft], origin: .camera)))))
    ) { $0.modal = .mediaSummary(expectedSummary) }
    await store.send(.modal(.presented(.mediaSummary(.delegate(.didRequestRetake(.camera)))))) {
      $0.modal = .capture(expectedCapture)
    }
    await store.send(
      .modal(.presented(.capture(.delegate(.didFinishCapture([Self.draft], origin: .camera)))))
    ) { $0.modal = .mediaSummary(expectedSummary) }
    await store.send(
      .modal(.presented(.mediaSummary(.delegate(.didSave(mode: .localOnly, captureAnother: true)))))
    ) { $0.modal = .capture(expectedCapture) }
    await store.receive(.apartmentsList(.reloadLocalState))
    await store.receive(
      .path(.element(id: timelineId, action: .apartmentTimeline(.reloadLocalState))))
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
