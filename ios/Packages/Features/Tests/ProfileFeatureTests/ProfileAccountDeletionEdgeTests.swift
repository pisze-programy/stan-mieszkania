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

@Suite("ProfileFeature Account Deletion Edge Cases")
struct ProfileAccountDeletionEdgeTests {
  @MainActor
  @Test("Cancelling Apple re-auth aborts account deletion cleanly without wiping")
  func accountDeletionAbortOnAppleCancellation() async throws {
    let database = try ProfileTestFixtures.makeSeededDatabase()
    let apiCalls = LockIsolated(0)
    let sessionCleared = LockIsolated(0)

    let store = TestStore(
      initialState: ProfileFeature.State(
        user: ProfileTestFixtures.initialUser,
        deleteAccountStep: .finalConfirm
      )
    ) {
      ProfileFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.authClient.loadStoredSession = { ProfileTestFixtures.appleSession }
      $0.authClient.requestFreshAppleAuthorizationCode = { throw AuthClientError.cancelled }
      $0.authClient.clearSession = { sessionCleared.withValue { $0 += 1 } }
      $0.apiClient.deleteMyAccount = { _ in apiCalls.withValue { $0 += 1 } }
    }

    await store.send(.deleteAccountConfirmed) {
      $0.isDeletingAccount = true
    }
    await store.receive(.deleteAccountCancelled) {
      $0.isDeletingAccount = false
      $0.deleteAccountStep = nil
    }

    let counts = try ProfileTestFixtures.tableCounts(in: database)
    #expect(counts == .seeded)
    #expect(apiCalls.value == 0)
    #expect(sessionCleared.value == 0)
  }

  @MainActor
  @Test("API failure during account deletion preserves local data and session for retry")
  func accountDeletionAPIFailurePreservesLocalData() async throws {
    let database = try ProfileTestFixtures.makeSeededDatabase()
    let sessionCleared = LockIsolated(0)
    let errorHaptics = LockIsolated(0)

    let store = TestStore(
      initialState: ProfileFeature.State(
        user: ProfileTestFixtures.initialUser,
        deleteAccountStep: .finalConfirm
      )
    ) {
      ProfileFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.authClient.loadStoredSession = { ProfileTestFixtures.localDevSession }
      $0.authClient.clearSession = { sessionCleared.withValue { $0 += 1 } }
      $0.apiClient.deleteMyAccount = { _ in
        throw APIProblemError(
          status: ProfileTestFixtures.httpStatusInternalError,
          code: .known(.accountDeletionFailed),
          title: "Deletion failed",
          detail: "Retry later",
          requestId: nil
        )
      }
      $0.haptics.error = { errorHaptics.withValue { $0 += 1 } }
    }

    await store.send(.deleteAccountConfirmed) {
      $0.isDeletingAccount = true
    }
    await store.receive(
      .deleteAccountFailed(L10n.errorMessage(for: .accountDeletionFailed))
    ) {
      $0.isDeletingAccount = false
      $0.deleteAccountStep = nil
      $0.errorMessage = L10n.errorMessage(for: .accountDeletionFailed)
    }

    let counts = try ProfileTestFixtures.tableCounts(in: database)
    #expect(counts == .seeded)
    #expect(sessionCleared.value == 0)
    #expect(errorHaptics.value == 1)
  }

  @MainActor
  @Test("Local-dev session skips Apple re-auth and sends nil authorization code")
  func localDevAccountDeletionPassesNilAppleCode() async throws {
    let database = try ProfileTestFixtures.makeSeededDatabase()
    let receivedCode = LockIsolated<String?>("sentinel")
    let applePromptCalls = LockIsolated(0)

    let store = TestStore(
      initialState: ProfileFeature.State(
        user: ProfileTestFixtures.initialUser,
        deleteAccountStep: .finalConfirm
      )
    ) {
      ProfileFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.authClient.loadStoredSession = { ProfileTestFixtures.localDevSession }
      $0.authClient.requestFreshAppleAuthorizationCode = {
        applePromptCalls.withValue { $0 += 1 }
        return "unexpected"
      }
      $0.authClient.clearSession = {}
      $0.apiClient.deleteMyAccount = { code in receivedCode.setValue(code) }
      $0.mediaStorage.deleteLocalFile = { _ in }
    }

    await store.send(.deleteAccountConfirmed) {
      $0.isDeletingAccount = true
    }
    await store.receive(.deleteAccountSucceeded) {
      $0.isDeletingAccount = false
      $0.deleteAccountStep = nil
      $0.user = nil
    }
    await store.receive(\.delegate.didDeleteAccount)

    #expect(applePromptCalls.value == 0)
    #expect(receivedCode.value == nil)
  }
}
