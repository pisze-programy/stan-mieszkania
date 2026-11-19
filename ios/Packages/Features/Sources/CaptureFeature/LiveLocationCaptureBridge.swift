import CoreLocation
import Domain
import Foundation

@MainActor
final class LiveLocationCaptureBridge: NSObject, CLLocationManagerDelegate {
  static let shared = LiveLocationCaptureBridge()

  private let manager: CLLocationManager
  private var authorizationContinuation: CheckedContinuation<LocationAuthorizationStatus, Never>?
  private var authorizationTimeoutTask: Task<Void, Never>?
  private var locationContinuation: CheckedContinuation<CaptureLocationMetadata?, Never>?
  private var timeoutTask: Task<Void, Never>?

  override init() {
    self.manager = CLLocationManager()
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  nonisolated static func currentAuthorizationStatus() -> LocationAuthorizationStatus {
    let raw = CLLocationManager().authorizationStatus
    return mapAuthorizationStatus(raw)
  }

  // Decision Q10: Bounded authorization timeout ensures GPS prompt can never block camera capture.
  func requestAuthorization(
    timeoutSeconds: Double = CaptureConstants.authorizationTimeoutSeconds
  ) async -> LocationAuthorizationStatus {
    let current = Self.mapAuthorizationStatus(manager.authorizationStatus)
    guard current == .notDetermined else {
      return current
    }

    return await withCheckedContinuation { continuation in
      finishAuthorizationRequest(with: current)
      authorizationContinuation = continuation
      authorizationTimeoutTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(timeoutSeconds))
        guard let self else {
          return
        }
        let latest = Self.mapAuthorizationStatus(self.manager.authorizationStatus)
        self.finishAuthorizationRequest(with: latest)
      }
      manager.requestWhenInUseAuthorization()
    }
  }

  // Decision Q10: Optional GPS capture must time out quickly and never block camera capture.
  func captureCurrentLocation(timeoutSeconds: Double) async -> CaptureLocationMetadata? {
    let status = Self.mapAuthorizationStatus(manager.authorizationStatus)
    guard status == .authorized else {
      return nil
    }

    return await withCheckedContinuation { continuation in
      finishLocationRequest(with: nil)
      locationContinuation = continuation
      timeoutTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(timeoutSeconds))
        self?.finishLocationRequest(with: nil)
      }
      manager.requestLocation()
    }
  }

  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let mapped = Self.mapAuthorizationStatus(manager.authorizationStatus)
    Task { @MainActor [weak self] in
      guard let self, mapped != .notDetermined else {
        return
      }
      self.finishAuthorizationRequest(with: mapped)
    }
  }

  nonisolated func locationManager(
    _ manager: CLLocationManager,
    didUpdateLocations locations: [CLLocation]
  ) {
    let metadata: CaptureLocationMetadata? = locations.last.map { location in
      let accuracy = location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil
      return CaptureLocationMetadata(
        lat: location.coordinate.latitude,
        lng: location.coordinate.longitude,
        accuracyM: accuracy,
        locationSource: .device
      )
    }
    Task { @MainActor [weak self] in
      self?.finishLocationRequest(with: metadata)
    }
  }

  nonisolated func locationManager(
    _ manager: CLLocationManager,
    didFailWithError error: any Error
  ) {
    Task { @MainActor [weak self] in
      self?.finishLocationRequest(with: nil)
    }
  }

  private func finishAuthorizationRequest(with status: LocationAuthorizationStatus) {
    authorizationTimeoutTask?.cancel()
    authorizationTimeoutTask = nil
    authorizationContinuation?.resume(returning: status)
    authorizationContinuation = nil
  }

  private func finishLocationRequest(with metadata: CaptureLocationMetadata?) {
    timeoutTask?.cancel()
    timeoutTask = nil
    locationContinuation?.resume(returning: metadata)
    locationContinuation = nil
  }

  private nonisolated static func mapAuthorizationStatus(
    _ status: CLAuthorizationStatus
  ) -> LocationAuthorizationStatus {
    switch status {
    case .notDetermined:
      return .notDetermined
    case .denied:
      return .denied
    case .restricted:
      return .restricted
    #if os(iOS)
      case .authorizedWhenInUse, .authorizedAlways:
        return .authorized
    #else
      case .authorizedAlways:
        return .authorized
    #endif
    @unknown default:
      return .denied
    }
  }
}
