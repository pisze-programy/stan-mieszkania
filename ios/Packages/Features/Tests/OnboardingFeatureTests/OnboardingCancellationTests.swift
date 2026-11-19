import AuthClient
import ComposableArchitecture
import Database
import DesignSystem
import Testing

@testable import OnboardingFeature

@Suite("OnboardingFeature Cancellation Tests")
struct OnboardingCancellationTests {
  private actor Recorder {
    var clearSessionCount = 0
    var errorHapticCount = 0

    func recordClearSession() { clearSessionCount += 1 }
    func recordErrorHaptic() { errorHapticCount += 1 }
  }

  @MainActor
  @Test("Handles cancelled Sign in with Apple cleanly without error banner or session clear")
  func cancelledAppleSignInShowsNoError() async throws {
    let database = try makeInMemoryDatabase()
    let recorder = Recorder()

    let store = TestStore(initialState: OnboardingFeature.State()) {
      OnboardingFeature()
    } withDependencies: {
      $0.defaultDatabase = database
      $0.authClient.signInWithApple = {
        throw AuthClientError.cancelled
      }
      $0.authClient.clearSession = {
        await recorder.recordClearSession()
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
    await store.receive(.authCancelled) {
      $0.isSigningIn = false
    }

    #expect(store.state.errorMessage == nil)
    #expect(await recorder.clearSessionCount == 0)
    #expect(await recorder.errorHapticCount == 0)
  }
}
