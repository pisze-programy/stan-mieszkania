import Dependencies
import DesignSystem

enum HapticsClientKey: DependencyKey {
  static let liveValue: HapticsClient = .live
  static let testValue: HapticsClient = .noop
}

extension DependencyValues {
  var hapticsClient: HapticsClient {
    get { self[HapticsClientKey.self] }
    set { self[HapticsClientKey.self] = newValue }
  }
}
