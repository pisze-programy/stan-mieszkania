import Dependencies
import DependenciesMacros
import Domain
import Foundation

public enum LocationAuthorizationStatus: Equatable, Sendable {
  case notDetermined
  case authorized
  case denied
  case restricted
}

@DependencyClient
public struct LocationCaptureClient: Sendable {
  public var authorizationStatus: @Sendable () -> LocationAuthorizationStatus = { .denied }
  public var hasDismissedPrompt: @Sendable () -> Bool = { false }
  public var markPromptDismissed: @Sendable () -> Void = {}
  public var requestWhenInUseAuthorization: @Sendable () async -> LocationAuthorizationStatus = {
    .denied
  }
  public var captureCurrentLocation: @Sendable () async -> CaptureLocationMetadata? = { nil }

  public static func live(
    timeoutSeconds: Double = CaptureConstants.locationTimeoutSeconds
  ) -> Self {
    Self(
      authorizationStatus: {
        LiveLocationCaptureBridge.currentAuthorizationStatus()
      },
      hasDismissedPrompt: {
        UserDefaults.standard.bool(forKey: CaptureConstants.gpsPromptDismissedDefaultsKey)
      },
      markPromptDismissed: {
        UserDefaults.standard.set(true, forKey: CaptureConstants.gpsPromptDismissedDefaultsKey)
      },
      requestWhenInUseAuthorization: {
        await MainActor.run {
          LiveLocationCaptureBridge.shared
        }.requestAuthorization()
      },
      captureCurrentLocation: {
        await MainActor.run {
          LiveLocationCaptureBridge.shared
        }.captureCurrentLocation(timeoutSeconds: timeoutSeconds)
      }
    )
  }
}

extension LocationCaptureClient: DependencyKey {
  public static var liveValue: LocationCaptureClient {
    .live()
  }

  public static var testValue: LocationCaptureClient {
    LocationCaptureClient()
  }
}

extension DependencyValues {
  public var locationCapture: LocationCaptureClient {
    get { self[LocationCaptureClient.self] }
    set { self[LocationCaptureClient.self] = newValue }
  }
}
