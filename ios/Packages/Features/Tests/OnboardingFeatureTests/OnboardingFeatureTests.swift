import APIClient
import AuthClient
import ComposableArchitecture
import Database
import DesignSystem
import Domain
import Foundation
import Testing

@testable import OnboardingFeature

@Suite("OnboardingFeature Tests")
struct OnboardingFeatureTests {
  private enum Fixtures {
    static let userId = "01933e2a-7b40-7000-8000-000000000001"
    static let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    static let forbiddenStatus = 403
    static let profile = UserProfile(
      id: userId,
      displayName: "Jan Kowalski",
      shortTag: "A1B2",
      color: DomainConstants.defaultAuthorColor,
      createdAt: createdAt
    )
    static let session = AuthSession(
      firebaseUid: "apple-uid-1",
      displayName: "Jan Kowalski",
      bearerToken: "token-123",
      appleAuthorizationCode: "auth-code-1"
    )
  }

  private actor Recorder {
    var signInAppleCount = 0
    var localDevArgs: [(String, String?)] = []
    var clearSessionCount = 0
    var successHapticCount = 0
    var errorHapticCount = 0

    func recordSignInApple() { signInAppleCount += 1 }
    func recordLocalDev(uid: String, name: String?) { localDevArgs.append((uid, name)) }
    func recordClearSession() { clearSessionCount += 1 }
    func recordSuccessHaptic() { successHapticCount += 1 }
    func recordErrorHaptic() { errorHapticCount += 1 }
  }

  @MainActor
  @Test("Sign in with Apple fetches profile, persists LocalUserRecord, and emits delegate")
  func signInWithAppleSuccess() async throws {
    let database = try makeInMemoryDatabase()
    let recorder = Recorder()

    let store = TestStore(initialState: OnboardingFeature.State()) {
      OnboardingFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.authClient.signInWithApple = {
        await recorder.recordSignInApple()
        return Fixtures.session
      }
      $0.apiClient.getMyProfile = {
        Fixtures.profile
      }
      $0.haptics = HapticsClient(
        markerDropped: {},
        actionSucceeded: { Task { await recorder.recordSuccessHaptic() } },
        warning: {},
        error: { Task { await recorder.recordErrorHaptic() } }
      )
    }

    await store.send(.signInWithAppleTapped) {
      $0.isSigningIn = true
    }
    await store.receive(\.authSucceeded) {
      $0.isSigningIn = false
    }
    await store.receive(\.delegate.didAuthenticate)

    let persisted = try ApartmentMutationStore(database: database).fetchCurrentUser()
    #expect(persisted == Fixtures.profile)
    #expect(await recorder.signInAppleCount == 1)
    #expect(await recorder.successHapticCount == 1)
  }

  @MainActor
  @Test("Ignores duplicate sign-in actions while sign-in is already in progress")
  func ignoresDuplicateSignInWhileBusy() async {
    let store = TestStore(initialState: OnboardingFeature.State(isSigningIn: true)) {
      OnboardingFeature()
    }
    await store.send(.signInWithAppleTapped)
    await store.send(.localDevSignInSubmitted(uid: "dev", displayName: nil))
  }

  @MainActor
  @Test("Maps APIProblemError to localized Polish message, clears session, and dismisses error")
  func apiProblemFailureAndDismissal() async throws {
    let database = try makeInMemoryDatabase()
    let recorder = Recorder()
    let problem = APIProblemError(
      status: Fixtures.forbiddenStatus,
      code: .known(.userDeleted),
      title: "Forbidden",
      detail: "User deleted"
    )

    let store = TestStore(initialState: OnboardingFeature.State()) {
      OnboardingFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.authClient.signInWithApple = {
        Fixtures.session
      }
      $0.authClient.clearSession = {
        await recorder.recordClearSession()
      }
      $0.apiClient.getMyProfile = {
        throw problem
      }
      $0.haptics = HapticsClient(
        markerDropped: {},
        actionSucceeded: {},
        warning: {},
        error: { Task { await recorder.recordErrorHaptic() } }
      )
    }

    await store.send(.signInWithAppleTapped) {
      $0.isSigningIn = true
    }
    let expectedMessage = L10n.errorMessage(for: .known(.userDeleted))
    await store.receive(.authFailed(expectedMessage)) {
      $0.isSigningIn = false
      $0.errorMessage = expectedMessage
    }
    await store.send(.dismissError) {
      $0.errorMessage = nil
    }

    #expect(await recorder.clearSessionCount == 1)
    #expect(await recorder.errorHapticCount == 1)
    #expect(try ApartmentMutationStore(database: database).fetchCurrentUser() == nil)
  }

  @MainActor
  @Test("Local dev login presents sheet, authenticates, persists user, and emits delegate")
  func localDevLoginFlow() async throws {
    let database = try makeInMemoryDatabase()
    let recorder = Recorder()

    let store = TestStore(
      initialState: OnboardingFeature.State(isLocalDevLoginEnabled: true)
    ) {
      OnboardingFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.authClient.signInLocalDev = { uid, name in
        await recorder.recordLocalDev(uid: uid, name: name)
        return AuthSession(firebaseUid: uid, displayName: name, bearerToken: "dev:\(uid)")
      }
      $0.apiClient.getMyProfile = {
        Fixtures.profile
      }
      $0.haptics = .noop
    }

    await store.send(.localDevSignInSheetPresented(true)) {
      $0.isLocalDevSheetPresented = true
    }
    await store.send(.localDevSignInSubmitted(uid: "dev-tenant", displayName: "Jan")) {
      $0.isLocalDevSheetPresented = false
      $0.isSigningIn = true
    }
    await store.receive(\.authSucceeded) {
      $0.isSigningIn = false
    }
    await store.receive(\.delegate.didAuthenticate)

    let calls = await recorder.localDevArgs
    #expect(calls.count == 1)
    #expect(calls.first?.0 == "dev-tenant")
    #expect(calls.first?.1 == "Jan")
    #expect(try ApartmentMutationStore(database: database).fetchCurrentUser() == Fixtures.profile)
  }

  @MainActor
  @Test("Instantiates OnboardingView and AmbientVideoBackgroundView cleanly")
  func instantiatesViews() {
    let store = Store(initialState: OnboardingFeature.State(isLocalDevLoginEnabled: true)) {
      OnboardingFeature()
    }
    let view = OnboardingView(store: store)
    let fallbackBg = AmbientVideoBackgroundView(videoURL: nil)
    _ = (view, fallbackBg)
  }
}
