import APIClient
import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import SQLiteData
import Testing

@testable import ProfileFeature

@Suite("ProfileFeature Name, Refresh, and Theme Tests")
struct ProfileNameAndThemeTests {
  @MainActor
  @Test("Task loads local profile and theme then refreshes from API")
  func taskLoadsLocalAndRemoteProfile() async throws {
    let database = try ProfileTestFixtures.makeSeededDatabase()

    let store = TestStore(initialState: ProfileFeature.State()) {
      ProfileFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.themePreference = ThemePreferenceClient(load: { .light }, save: { _ in })
      $0.apiClient.getMyProfile = { ProfileTestFixtures.updatedUser }
    }

    await store.send(.task) { $0.isLoading = true }
    await store.receive(
      .localProfileLoaded(ProfileTestFixtures.initialUser, theme: .light, localOnlyMediaCount: 0)
    ) {
      $0.user = ProfileTestFixtures.initialUser
      $0.displayNameInput = ProfileTestFixtures.initialUser.displayName
      $0.selectedTheme = .light
    }
    await store.receive(.remoteProfileLoaded(ProfileTestFixtures.updatedUser)) {
      $0.isLoading = false
      $0.user = ProfileTestFixtures.updatedUser
      $0.displayNameInput = ProfileTestFixtures.updatedUser.displayName
    }
    await store.receive(.delegate(.didUpdateProfile(ProfileTestFixtures.updatedUser)))

    let memberName = try await database.read { db in
      try MemberRecord.where { $0.userId.eq(ProfileTestFixtures.userId) }.fetchOne(db)?.displayName
    }
    #expect(memberName == ProfileTestFixtures.updatedUser.displayName)
  }

  @Test("isNameDirty truth table gates Save toolbar item visibility accurately")
  func isNameDirtyTruthTable() {
    let base = ProfileFeature.State(user: ProfileTestFixtures.initialUser)
    #expect(!base.isNameDirty)

    var whitespacePadded = base
    whitespacePadded.displayNameInput = "  Jan Kowalski  "
    #expect(!whitespacePadded.isNameDirty)

    var blank = base
    blank.displayNameInput = "   "
    #expect(!blank.isNameDirty)

    var tooLong = base
    tooLong.displayNameInput = String(
      repeating: "a", count: ContractConstants.displayNameMaxLength + 1)
    #expect(!tooLong.isNameDirty)

    var modified = base
    modified.displayNameInput = "Anna Nowak"
    #expect(modified.isNameDirty)
  }

  @MainActor
  @Test("Invalid display name fails validation locally with warning haptic")
  func invalidDisplayNameShowsValidationError() async {
    let warningCount = LockIsolated(0)
    let apiCalls = LockIsolated(0)

    let store = TestStore(
      initialState: ProfileFeature.State(
        user: ProfileTestFixtures.initialUser,
        displayNameInput: "   "
      )
    ) {
      ProfileFeature()
    } withDependencies: {
      $0.apiClient.updateMyProfile = { _ in
        apiCalls.withValue { $0 += 1 }
        return ProfileTestFixtures.updatedUser
      }
      $0.haptics.warning = { warningCount.withValue { $0 += 1 } }
    }

    await store.send(.saveDisplayNameTapped) {
      $0.errorMessage = L10n.errorMessage(for: .displayNameInvalid)
    }

    #expect(apiCalls.value == 0)
    #expect(warningCount.value == 1)
  }

  @MainActor
  @Test("Valid display name update persists, fires haptic, and auto-resets saved checkmark in 1.5s")
  func saveDisplayNameUpdatesLocalUserAndAutoResetsFeedback() async throws {
    let database = try ProfileTestFixtures.makeSeededDatabase()
    let clock = TestClock()
    let submittedName = LockIsolated<String?>(nil)
    let successHaptics = LockIsolated(0)

    let store = TestStore(
      initialState: ProfileFeature.State(user: ProfileTestFixtures.initialUser)
    ) {
      ProfileFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.continuousClock = clock
      $0.apiClient.updateMyProfile = { name in
        submittedName.setValue(name)
        return ProfileTestFixtures.updatedUser
      }
      $0.haptics.actionSucceeded = { successHaptics.withValue { $0 += 1 } }
    }

    await store.send(.displayNameChanged("  Anna Nowak  ")) {
      $0.displayNameInput = "  Anna Nowak  "
    }
    #expect(store.state.isNameDirty)
    await store.send(.saveDisplayNameTapped) { $0.isSavingName = true }
    await store.receive(.saveDisplayNameSucceeded(ProfileTestFixtures.updatedUser)) {
      $0.isSavingName = false
      $0.user = ProfileTestFixtures.updatedUser
      $0.displayNameInput = ProfileTestFixtures.updatedUser.displayName
      $0.showNameSavedFeedback = true
    }
    await store.receive(.delegate(.didUpdateProfile(ProfileTestFixtures.updatedUser)))
    #expect(!store.state.isNameDirty)

    await clock.advance(by: .milliseconds(ProfileFeature.savedFeedbackDurationMilliseconds))
    await store.receive(.dismissNameSavedFeedback) { $0.showNameSavedFeedback = false }

    #expect(submittedName.value == "Anna Nowak")
    #expect(successHaptics.value == 1)
    let storedUser = try ProfileStore.fetchCurrentUser(from: database)
    #expect(storedUser?.displayName == "Anna Nowak")
  }

  @MainActor
  @Test("Theme switch persists preference, notifies delegate, and views instantiate cleanly")
  func themeSwitchAndViewInstantiation() async {
    let savedThemes = LockIsolated<[AppThemePreference]>([])

    let store = TestStore(initialState: ProfileFeature.State()) {
      ProfileFeature()
    } withDependencies: {
      $0.themePreference = ThemePreferenceClient(
        load: { .system },
        save: { theme in savedThemes.withValue { $0.append(theme) } }
      )
    }

    await store.send(.themeChanged(.dark)) { $0.selectedTheme = .dark }
    await store.receive(\.delegate.didChangeTheme)
    #expect(savedThemes.value == [.dark])

    let viewStore = Store(
      initialState: ProfileFeature.State(user: ProfileTestFixtures.initialUser)
    ) {
      ProfileFeature()
    }
    _ = (
      ProfileView(store: viewStore),
      DeleteAccountImpactSheetView(
        step: .impact,
        isDeleting: false,
        onContinue: {},
        onConfirm: {},
        onCancel: {}
      ),
    )
  }
}
