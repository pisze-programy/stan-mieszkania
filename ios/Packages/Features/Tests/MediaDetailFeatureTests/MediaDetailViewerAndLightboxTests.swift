import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import Testing

@testable import MediaDetailFeature

@Suite("MediaDetailFeature Markers Visibility and Lightbox Tests")
struct MediaDetailViewerAndLightboxTests {
  private static let markerTwoNumber = 2

  @MainActor
  @Test("Overlay markers use MarkerPalette colors per marker number, not author colors")
  func overlayMarkersUseMarkerPaletteColors() throws {
    let database = try MediaDetailTestFixtures.seedDatabase(
      activeRole: .owner,
      isVerifiedMedia: true
    )
    let snapshot = try MediaDetailStore.fetchSnapshot(
      mediaId: MediaDetailTestFixtures.mediaId,
      from: database
    )
    let state = MediaDetailFeature.State(
      apartmentId: MediaDetailTestFixtures.apartmentId,
      mediaId: MediaDetailTestFixtures.mediaId,
      media: snapshot.media,
      entries: snapshot.entries,
      currentUser: snapshot.currentUser,
      hasOtherMembers: snapshot.hasOtherMembers
    )

    let overlay = state.overlayMarkers
    #expect(overlay.count == Self.markerTwoNumber)
    #expect(overlay[0].colorHex == MarkerPalette.hex(forMarkerNumber: 1))
    #expect(overlay[1].colorHex == MarkerPalette.hex(forMarkerNumber: Self.markerTwoNumber))
    #expect(overlay[0].colorHex != overlay[1].colorHex)
    #expect(state.hasOtherMembers)
  }

  @MainActor
  @Test("Hide markers toggle, token auto-unhide, toggle-off selection, and lightbox grammar")
  func markerVisibilitySelectionAndLightboxGrammar() async throws {
    let database = try MediaDetailTestFixtures.seedDatabase(
      activeRole: .owner,
      isVerifiedMedia: true
    )
    let snapshot = try MediaDetailStore.fetchSnapshot(
      mediaId: MediaDetailTestFixtures.mediaId,
      from: database
    )
    let store = TestStore(
      initialState: MediaDetailFeature.State(
        apartmentId: MediaDetailTestFixtures.apartmentId,
        mediaId: MediaDetailTestFixtures.mediaId,
        media: snapshot.media,
        entries: snapshot.entries,
        currentUser: snapshot.currentUser,
        hasOtherMembers: snapshot.hasOtherMembers
      )
    ) {
      MediaDetailFeature()
    }

    await store.send(.markersVisibilityToggled) { $0.areMarkersHidden = true }

    await store.send(.markerTapped(Self.markerTwoNumber)) {
      $0.areMarkersHidden = false
      $0.selectedMarkerNumber = Self.markerTwoNumber
      $0.scrollTargetEntryId = MediaDetailTestFixtures.entryTwoId
    }
    #expect(store.state.selectedLightboxCaption?.markerNumber == Self.markerTwoNumber)
    #expect(store.state.selectedLightboxCaption?.entryText == "Odprysk farby [2]")

    await store.send(.photoTapped) {
      $0.selectedMarkerNumber = nil
      $0.scrollTargetEntryId = nil
    }
    #expect(!store.state.isLightboxPresented)

    await store.send(.photoTapped) { $0.isLightboxPresented = true }
    await store.send(.lightboxDismissed) { $0.isLightboxPresented = false }

    await store.send(.markerTapped(1)) {
      $0.selectedMarkerNumber = 1
      $0.scrollTargetEntryId = MediaDetailTestFixtures.entryOneId
    }
    await store.send(.markerTapped(1)) {
      $0.selectedMarkerNumber = nil
      $0.scrollTargetEntryId = nil
    }
  }

  @MainActor
  @Test("Composer placement mode forces markers visible and ignores photoTapped lightbox")
  func composerPlacementForcesMarkersVisibleAndBlocksLightbox() async throws {
    let database = try MediaDetailTestFixtures.seedDatabase(
      activeRole: .owner,
      isVerifiedMedia: true
    )
    let snapshot = try MediaDetailStore.fetchSnapshot(
      mediaId: MediaDetailTestFixtures.mediaId,
      from: database
    )
    let store = TestStore(
      initialState: MediaDetailFeature.State(
        apartmentId: MediaDetailTestFixtures.apartmentId,
        mediaId: MediaDetailTestFixtures.mediaId,
        media: snapshot.media,
        entries: snapshot.entries,
        currentUser: snapshot.currentUser,
        hasOtherMembers: snapshot.hasOtherMembers,
        areMarkersHidden: true
      )
    ) {
      MediaDetailFeature()
    }

    await store.send(.addEntryTapped) { $0.composer = EntryComposerState() }
    await store.send(.composerToggleMarkerMode) {
      $0.composer?.isMarkerPlacementMode = true
      $0.areMarkersHidden = false
    }
    await store.send(.photoTapped)
    #expect(!store.state.isLightboxPresented)
  }
}
