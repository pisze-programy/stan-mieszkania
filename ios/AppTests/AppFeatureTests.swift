import ApartmentTimelineFeature
import ApartmentsListFeature
import AppConfigClient
import AuthClient
import ComposableArchitecture
import Database
import Domain
import Foundation
import MediaDetailFeature
import OnboardingFeature
import ProfileFeature
import SQLiteData
import SyncEngine
import Testing

@testable import StanMieszkania

@Suite("AppFeature Auth, Detail, and Profile Routing Tests")
struct AppFeatureTests {
  static let userId = "01933e2a-7b40-7000-8000-000000000001"
  static let apartmentId = "01933e2a-7b40-7000-8000-000000000010"
  static let mediaId = "01933e2a-7b40-7000-8000-000000000101"
  private static let baseEpoch: TimeInterval = 1_700_000_000
  static let baseDate = Date(timeIntervalSince1970: baseEpoch)

  static let profile = UserProfile(
    id: userId,
    displayName: "Jan Kowalski",
    shortTag: "A1B2",
    color: "#007AFF",
    createdAt: baseDate
  )

  static let author = AuthorSummary(
    userId: userId,
    displayName: "Jan Kowalski",
    shortTag: "A1B2",
    color: "#007AFF",
    role: .owner
  )

  private static let upToDateConfig = ResolvedAppConfig(
    config: .fallbackDefaults,
    updateStatus: .upToDate,
    isFromCacheOrFallback: false
  )

  private static let expectedCloudCount = 5
  private static let sampleApartment = Apartment(
    id: apartmentId,
    ownerId: userId,
    name: "Kawalerka Mokotów",
    street: "Puławska 10",
    city: "Warszawa",
    role: .owner,
    cloudMediaCount: expectedCloudCount,
    createdAt: baseDate,
    updatedAt: baseDate
  )

  @MainActor
  @Test("Boots unauthenticated, authenticates via Onboarding, and pushes hydrated timeline")
  func bootAuthenticateAndPushTimeline() async throws {
    let database = try makeInMemoryDatabase()
    let listItem = ApartmentListItem(
      apartment: Self.sampleApartment,
      photoCount: Self.expectedCloudCount
    )
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.date.now = Self.baseDate
      $0.authClient.loadStoredSession = { nil }
      $0.themePreference.load = { .light }
      $0.appConfigClient.refresh = { Self.upToDateConfig }
      $0.syncEngine.events = { AsyncStream { $0.finish() } }
    }

    await store.send(.task)
    let resolved = AppFeature.Action.bootstrapResolved(
      isAuthenticated: false,
      currentUser: nil,
      theme: .light
    )
    await store.receive(resolved) {
      $0.isBootstrapping = false
      $0.isAuthenticated = false
      $0.themePreference = .light
    }
    await store.receive(.appConfigResolved(Self.upToDateConfig))

    await store.send(.onboarding(.delegate(.didAuthenticate(Self.profile)))) {
      $0.isAuthenticated = true
      $0.currentUser = Self.profile
      $0.apartmentsList = ApartmentsListFeature.State(currentUser: Self.profile)
    }
    await store.send(.apartmentsList(.delegate(.didSelectApartment(listItem)))) {
      $0.path.append(
        .apartmentTimeline(
          ApartmentTimelineFeature.State(
            apartmentId: Self.apartmentId,
            apartment: Self.sampleApartment,
            cloudMediaCount: Self.expectedCloudCount,
            now: Self.baseDate
          )
        )
      )
    }
  }

  @MainActor
  @Test("Routes media detail delete, profile theme update, and sign out reset cleanly")
  func mediaDetailProfileThemeAndSignOutFlow() async throws {
    let database = try makeInMemoryDatabase()
    let store = makeAuthenticatedStore(database: database)
    store.exhaustivity = .off

    let timelineId = try #require(store.state.path.ids.first)
    await store.send(
      .path(
        .element(
          id: timelineId,
          action: .apartmentTimeline(.delegate(.didSelectMedia(mediaId: Self.mediaId)))
        )
      )
    )
    let detailId = try #require(store.state.path.ids.last)
    await store.send(
      .path(
        .element(
          id: detailId,
          action: .mediaDetail(.delegate(.didDeleteLocalMedia(mediaId: Self.mediaId)))
        )
      )
    )
    #expect(store.state.path.count == 1)

    let updatedProfile = UserProfile(
      id: Self.userId,
      displayName: "Anna Nowak",
      shortTag: "A1B2",
      color: "#007AFF",
      createdAt: Self.baseDate
    )
    await store.send(.apartmentsList(.delegate(.didTapProfile)))
    let profileId = try #require(store.state.path.ids.last)
    await store.send(
      .path(.element(id: profileId, action: .profile(.delegate(.didUpdateProfile(updatedProfile)))))
    )
    #expect(store.state.currentUser == updatedProfile)
    #expect(store.state.apartmentsList.currentUser == updatedProfile)

    await store.send(
      .path(.element(id: profileId, action: .profile(.delegate(.didChangeTheme(.dark)))))
    )
    #expect(store.state.themePreference == .dark)

    await store.send(.path(.element(id: profileId, action: .profile(.delegate(.didSignOut)))))
    #expect(!store.state.isAuthenticated)
    #expect(store.state.currentUser == nil)
    #expect(store.state.path.isEmpty)
  }

  @MainActor
  private func makeAuthenticatedStore(database: any DatabaseWriter) -> TestStoreOf<AppFeature> {
    var initial = AppFeature.State(
      isBootstrapping: false,
      isAuthenticated: true,
      themePreference: .system,
      currentUser: Self.profile,
      apartmentsList: ApartmentsListFeature.State(currentUser: Self.profile)
    )
    initial.path.append(
      .apartmentTimeline(ApartmentTimelineFeature.State(apartmentId: Self.apartmentId))
    )
    return TestStore(initialState: initial) {
      AppFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.date.now = Self.baseDate
      $0.calendar = Calendar(identifier: .gregorian)
      $0.timeZone = .gmt
      $0.syncEngine.events = { AsyncStream { $0.finish() } }
    }
  }
}
