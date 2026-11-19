import ComposableArchitecture
import Domain
import Foundation
import Testing

@testable import MediaSummaryFeature

@Suite("MediaSummaryFeature Markers and Multi-Photo Pager Tests")
struct MediaSummaryMarkersAndPagerTests {
  private static let markerOneX = 0.25
  private static let markerOneY = 0.4
  private static let markerTwoX = 0.8
  private static let markerTwoY = 0.6
  private static let twoMarkersCount = 2

  @MainActor
  @Test("Markers sync live with text, restore on retype, purge orphans, and remove on menu")
  func textSyncedMarkersAndRemoval() async {
    let markerHaptics = LockIsolated(0)
    let store = makeStore(
      drafts: [MediaSummaryTestFixtures.makeDraft()],
      origin: .camera,
      markerHaptics: markerHaptics
    )
    let first = SummaryDraftMarker(
      id: MediaSummaryTestFixtures.markerOneId, number: 1,
      x: Self.markerOneX, y: Self.markerOneY
    )
    await store.send(.markerAddedAt(x: Self.markerOneX, y: Self.markerOneY)) {
      $0.pages[0].markers = [first]
      $0.pages[0].description = "[1] "
      $0.pages[0].selectedMarkerNumber = 1
    }
    #expect(store.state.pages[0].activeMarkers == [first])

    await store.send(.descriptionChanged(" rysa")) {
      $0.pages[0].description = " rysa"
      $0.pages[0].selectedMarkerNumber = nil
    }
    #expect(store.state.pages[0].activeMarkers.isEmpty)
    #expect(store.state.pages[0].markerOverlayItems().isEmpty)
    #expect(store.state.pages[0].markers == [first])

    await store.send(.descriptionChanged("[1] rysa")) { $0.pages[0].description = "[1] rysa" }
    #expect(store.state.pages[0].activeMarkers == [first])

    await store.send(.descriptionChanged("[99]")) { $0.pages[0].description = "[99]" }
    #expect(store.state.pages[0].activeMarkers.isEmpty)

    let freshOne = SummaryDraftMarker(
      id: MediaSummaryTestFixtures.markerTwoId, number: 1,
      x: Self.markerTwoX, y: Self.markerTwoY
    )
    await store.send(.markerAddedAt(x: Self.markerTwoX, y: Self.markerTwoY)) {
      $0.pages[0].markers = [freshOne]
      $0.pages[0].description = "[99] [1] "
      $0.pages[0].selectedMarkerNumber = 1
    }
    await store.send(.markerSelected(1)) { $0.pages[0].selectedMarkerNumber = nil }
    await store.send(.markerSelected(1)) { $0.pages[0].selectedMarkerNumber = 1 }
    await store.send(.markerRemoveRequested(1)) {
      $0.pages[0].markers = []
      $0.pages[0].description = "[99]"
      $0.pages[0].selectedMarkerNumber = nil
    }
    #expect(markerHaptics.value == Self.twoMarkersCount)
  }

  @MainActor
  @Test("Multi-photo pager isolates description and markers independently per photo")
  func multiPhotoPagerIsolatesPageState() async {
    let drafts = [
      MediaSummaryTestFixtures.makeDraft(
        id: MediaSummaryTestFixtures.draftOneId,
        origin: .photoLibrary
      ),
      MediaSummaryTestFixtures.makeDraft(
        id: MediaSummaryTestFixtures.draftTwoId,
        origin: .photoLibrary
      ),
    ]
    let store = makeStore(
      drafts: drafts,
      origin: .photoLibrary,
      markerHaptics: LockIsolated(0)
    )
    #expect(store.state.isMultiPhoto)

    let pageOneMarker = SummaryDraftMarker(
      id: MediaSummaryTestFixtures.markerOneId,
      number: 1,
      x: Self.markerOneX,
      y: Self.markerOneY
    )
    await store.send(.markerAddedAt(x: Self.markerOneX, y: Self.markerOneY)) {
      $0.pages[0].markers = [pageOneMarker]
      $0.pages[0].description = "[1] "
      $0.pages[0].selectedMarkerNumber = 1
    }

    await store.send(.pageSelected(1)) { $0.selectedIndex = 1 }
    await store.send(.descriptionChanged("Kuchnia - blat")) {
      $0.pages[1].description = "Kuchnia - blat"
    }
    let pageTwoMarker = SummaryDraftMarker(
      id: MediaSummaryTestFixtures.markerTwoId,
      number: 1,
      x: Self.markerTwoX,
      y: Self.markerTwoY
    )
    await store.send(.markerAddedAt(x: Self.markerTwoX, y: Self.markerTwoY)) {
      $0.pages[1].markers = [pageTwoMarker]
      $0.pages[1].description = "Kuchnia - blat [1] "
      $0.pages[1].selectedMarkerNumber = 1
    }

    await store.send(.pageSelected(0)) { $0.selectedIndex = 0 }
    #expect(store.state.pages[0].description == "[1] ")
    #expect(store.state.pages[1].description == "Kuchnia - blat [1] ")
  }

  @MainActor
  @Test("Ignores late descriptionChanged updates while save is in flight")
  func ignoresDescriptionChangedWhileSaving() async {
    var initialState = MediaSummaryFeature.State(
      apartmentId: MediaSummaryTestFixtures.apartmentId,
      drafts: [MediaSummaryTestFixtures.makeDraft()],
      origin: .camera,
      currentUser: MediaSummaryTestFixtures.author,
      savingMode: .cloud
    )
    initialState.pages[0].description = "Rysa"
    let store = TestStore(initialState: initialState) {
      MediaSummaryFeature()
    }
    await store.send(.descriptionChanged("Rysa po zamknieciu"))
    #expect(store.state.pages[0].description == "Rysa")
  }

  @MainActor
  private func makeStore(
    drafts: [CapturedPhotoDraft],
    origin: CaptureSourceKind,
    markerHaptics: LockIsolated<Int>
  ) -> TestStoreOf<MediaSummaryFeature> {
    TestStore(
      initialState: MediaSummaryFeature.State(
        apartmentId: MediaSummaryTestFixtures.apartmentId,
        drafts: drafts,
        origin: origin,
        currentUser: MediaSummaryTestFixtures.author
      )
    ) {
      MediaSummaryFeature()
    } withDependencies: {
      $0.idGenerator = MediaSummaryTestFixtures.makeIDGenerator([
        MediaSummaryTestFixtures.markerOneId,
        MediaSummaryTestFixtures.markerTwoId,
      ])
      $0.haptics.markerDropped = { markerHaptics.withValue { $0 += 1 } }
    }
  }
}
