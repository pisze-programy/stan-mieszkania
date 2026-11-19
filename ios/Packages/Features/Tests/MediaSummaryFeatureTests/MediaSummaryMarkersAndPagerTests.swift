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
  private static let outOfBoundsX = 1.5
  private static let outOfBoundsY = -0.2
  private static let twoMarkersCount = 2

  @MainActor
  @Test("Places touch-point markers with [n] tokens, deletes cleanly, and clears on outside tap")
  func markerPlacementDeletionAndOutsideDeselection() async {
    let markerHaptics = LockIsolated(0)
    let store = makeStore(
      drafts: [MediaSummaryTestFixtures.makeDraft()],
      origin: .camera,
      isPlacementMode: false,
      markerHaptics: markerHaptics
    )

    await store.send(.markerAddedAt(x: Self.markerOneX, y: Self.markerOneY))
    await store.send(.toggleMarkerPlacementMode) { $0.isMarkerPlacementMode = true }
    await store.send(.descriptionChanged("Rysa na ścianie")) {
      $0.pages[0].description = "Rysa na ścianie"
    }

    let first = SummaryDraftMarker(
      id: MediaSummaryTestFixtures.markerOneId,
      number: 1,
      x: Self.markerOneX,
      y: Self.markerOneY
    )
    await store.send(.markerAddedAt(x: Self.markerOneX, y: Self.markerOneY)) {
      $0.pages[0].markers = [first]
      $0.pages[0].description = "Rysa na ścianie [1]"
      $0.pages[0].selectedMarkerNumber = 1
    }

    let second = SummaryDraftMarker(
      id: MediaSummaryTestFixtures.markerTwoId,
      number: Self.twoMarkersCount,
      x: ContractConstants.markerCoordMax,
      y: ContractConstants.markerCoordMin
    )
    await store.send(.markerAddedAt(x: Self.outOfBoundsX, y: Self.outOfBoundsY)) {
      $0.pages[0].markers = [first, second]
      $0.pages[0].description = "Rysa na ścianie [1] [2]"
      $0.pages[0].selectedMarkerNumber = Self.twoMarkersCount
    }

    await store.send(.markerSelectionCleared) { $0.pages[0].selectedMarkerNumber = nil }
    await store.send(.markerSelected(1)) { $0.pages[0].selectedMarkerNumber = 1 }
    await store.send(.markerDeleted(1)) {
      $0.pages[0].markers = [second]
      $0.pages[0].description = "Rysa na ścianie [2]"
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
      isPlacementMode: true,
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
      $0.pages[0].description = "[1]"
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
      $0.pages[1].description = "Kuchnia - blat [1]"
      $0.pages[1].selectedMarkerNumber = 1
    }

    await store.send(.pageSelected(0)) { $0.selectedIndex = 0 }
    #expect(store.state.pages[0].description == "[1]")
    #expect(store.state.pages[1].description == "Kuchnia - blat [1]")
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
    isPlacementMode: Bool,
    markerHaptics: LockIsolated<Int>
  ) -> TestStoreOf<MediaSummaryFeature> {
    TestStore(
      initialState: MediaSummaryFeature.State(
        apartmentId: MediaSummaryTestFixtures.apartmentId,
        drafts: drafts,
        origin: origin,
        currentUser: MediaSummaryTestFixtures.author,
        isMarkerPlacementMode: isPlacementMode
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
