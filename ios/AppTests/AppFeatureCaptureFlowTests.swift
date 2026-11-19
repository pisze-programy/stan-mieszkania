import ApartmentTimelineFeature
import ApartmentsListFeature
import CaptureFeature
import ComposableArchitecture
import Database
import Domain
import Foundation
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
  @Test("Presents and dismisses Sharing modal from ApartmentTimelineFeature")
  func sharingModalFlow() async throws {
    let store = try makeTimelineStore()
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
  }

  @MainActor
  @Test("Routes Capture -> Summary -> Retake -> CaptureAnother loop")
  func captureSummaryRetakeLoopFlow() async throws {
    let store = try makeTimelineStore()
    let timelineId = try #require(store.state.path.ids.first)
    let captureAction = AppFeature.Action.path(
      .element(
        id: timelineId,
        action: .apartmentTimeline(
          .delegate(
            .didSelectCaptureSource(apartmentId: AppFeatureTests.apartmentId, source: .camera)
          )
        )
      )
    )
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

    await store.send(captureAction) { $0.modal = .capture(expectedCapture) }
    await store.send(
      .modal(.presented(.capture(.delegate(.didFinishCapture([Self.draft], origin: .camera)))))
    ) {
      $0.modal = .mediaSummary(expectedSummary)
    }
    await store.send(.modal(.presented(.mediaSummary(.delegate(.didRequestRetake(.camera)))))) {
      $0.modal = .capture(expectedCapture)
    }
    await store.send(
      .modal(.presented(.capture(.delegate(.didFinishCapture([Self.draft], origin: .camera)))))
    ) {
      $0.modal = .mediaSummary(expectedSummary)
    }
    await store.send(
      .modal(.presented(.mediaSummary(.delegate(.didSave(mode: .cloud, captureAnother: true)))))
    ) {
      $0.modal = .capture(expectedCapture)
    }
  }

  @MainActor
  private func makeTimelineStore() throws -> TestStoreOf<AppFeature> {
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
      $0.syncEngine.events = { AsyncStream { $0.finish() } }
    }
  }
}
