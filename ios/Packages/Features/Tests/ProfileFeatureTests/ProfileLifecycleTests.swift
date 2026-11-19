import APIClient
import AuthClient
import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import MediaStorage
import SQLiteData
import Testing

@testable import ProfileFeature

@Suite("ProfileFeature Sign Out and Account Deletion Tests")
struct ProfileLifecycleTests {
  private static let localOnlyMediaId = "01933e2a-7b40-7000-8000-000000000099"
  private static let twoLocalCount = 2

  @Test("Sign out confirmation adapts tone and Polish copy to localOnlyMediaCount")
  func signOutConfirmationAdaptsToLocalOnlyCount() async throws {
    let database = try ProfileTestFixtures.makeSeededDatabase()
    #expect(try ProfileStore.fetchLocalOnlyMediaCount(from: database) == 0)

    let localRecord = MediaRecord(
      id: Self.localOnlyMediaId,
      apartmentId: ProfileTestFixtures.apartmentId,
      authorId: ProfileTestFixtures.userId,
      kind: MediaKind.photo.rawValue,
      source: MediaSource.camera.rawValue,
      sha256: ProfileTestFixtures.sha256,
      capturedAt: ProfileTestFixtures.baseDate,
      capturedTz: "Europe/Warsaw",
      capturedAtFromImport: false,
      serverReceivedAt: nil,
      width: ProfileTestFixtures.width,
      height: ProfileTestFixtures.height,
      bytes: ProfileTestFixtures.bytes,
      syncState: MediaSyncState.localOnly.rawValue,
      localFilePath: "\(Self.localOnlyMediaId).jpg"
    )
    try await database.write { db in
      try MediaRecord.upsert { localRecord }.execute(db)
    }
    #expect(try ProfileStore.fetchLocalOnlyMediaCount(from: database) == 1)

    let safeState = ProfileFeature.State(
      user: ProfileTestFixtures.initialUser,
      localOnlyMediaCount: 0
    )
    #expect(safeState.signOutConfirmationContent.tone == .neutral)
    #expect(
      safeState.signOutConfirmationContent.message == L10n.string("profile.sign.out.message.safe")
    )

    let warningState = ProfileFeature.State(
      user: ProfileTestFixtures.initialUser,
      localOnlyMediaCount: Self.twoLocalCount
    )
    #expect(warningState.signOutConfirmationContent.tone == .destructive)
    #expect(
      warningState.signOutConfirmationContent.message
        == L10n.signOutLocalOnlyMessage(Self.twoLocalCount)
    )
  }

  @MainActor
  @Test("Sign out confirmation wipes SQLiteData, cached media, and session")
  func signOutWipesLocalStateAndSession() async throws {
    let database = try ProfileTestFixtures.makeSeededDatabase()
    let deletedMedia = LockIsolated<[String]>([])
    let sessionCleared = LockIsolated(0)
    let successHaptics = LockIsolated(0)

    let store = TestStore(
      initialState: ProfileFeature.State(user: ProfileTestFixtures.initialUser)
    ) {
      ProfileFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.mediaStorage.deleteLocalFile = { mediaId in deletedMedia.withValue { $0.append(mediaId) } }
      $0.authClient.clearSession = { sessionCleared.withValue { $0 += 1 } }
      $0.haptics.actionSucceeded = { successHaptics.withValue { $0 += 1 } }
    }

    await store.send(.signOutTapped) { $0.isSignOutConfirmationPresented = true }
    await store.send(.signOutConfirmed) {
      $0.isSignOutConfirmationPresented = false
      $0.isSigningOut = true
    }
    await store.receive(.signOutCompleted) {
      $0.isSigningOut = false
      $0.user = nil
    }
    await store.receive(\.delegate.didSignOut)

    let counts = try ProfileTestFixtures.tableCounts(in: database)
    #expect(counts == .empty)
    #expect(deletedMedia.value == [ProfileTestFixtures.mediaId])
    #expect(sessionCleared.value == 1)
    #expect(successHaptics.value == 1)
  }

  @MainActor
  @Test("Two-step delete sheet transitions in place, ignores dismiss while deleting, then wipes")
  func twoStepAccountDeletionHappyPath() async throws {
    let database = try ProfileTestFixtures.makeSeededDatabase()
    let receivedCode = LockIsolated<String?>(nil)
    let deletedMedia = LockIsolated<[String]>([])
    let sessionCleared = LockIsolated(0)
    let deleteGate = AsyncStream.makeStream(of: Void.self)

    let store = TestStore(
      initialState: ProfileFeature.State(user: ProfileTestFixtures.initialUser)
    ) {
      ProfileFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.authClient.loadStoredSession = { ProfileTestFixtures.appleSession }
      $0.authClient.requestFreshAppleAuthorizationCode = { "fresh-apple-code" }
      $0.authClient.clearSession = { sessionCleared.withValue { $0 += 1 } }
      $0.apiClient.deleteMyAccount = { code in
        receivedCode.setValue(code)
        for await _ in deleteGate.stream { break }
      }
      $0.mediaStorage.deleteLocalFile = { id in deletedMedia.withValue { $0.append(id) } }
    }

    await store.send(.deleteAccountTapped) { $0.deleteAccountStep = .impact }
    await store.send(.deleteImpactContinueTapped) { $0.deleteAccountStep = .finalConfirm }
    await store.send(.deleteAccountConfirmed) { $0.isDeletingAccount = true }
    await store.send(.deleteAccountSheetDismissed)
    #expect(store.state.deleteAccountStep == .finalConfirm)
    deleteGate.continuation.yield()
    deleteGate.continuation.finish()

    await store.receive(.deleteAccountSucceeded) {
      $0.isDeletingAccount = false
      $0.deleteAccountStep = nil
      $0.user = nil
    }
    await store.receive(\.delegate.didDeleteAccount)

    let counts = try ProfileTestFixtures.tableCounts(in: database)
    #expect(counts == .empty)
    #expect(receivedCode.value == "fresh-apple-code")
    #expect(deletedMedia.value == [ProfileTestFixtures.mediaId])
    #expect(sessionCleared.value == 1)
  }
}
