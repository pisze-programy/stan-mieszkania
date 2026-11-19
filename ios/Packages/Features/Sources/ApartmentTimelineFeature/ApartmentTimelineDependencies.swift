import Dependencies
import Domain

enum TimelineIDGeneratorKey: DependencyKey {
  static let liveValue: any IDGenerator = SystemIDGenerator()
  static let testValue: any IDGenerator = SystemIDGenerator()
}

extension DependencyValues {
  var idGenerator: any IDGenerator {
    get { self[TimelineIDGeneratorKey.self] }
    set { self[TimelineIDGeneratorKey.self] = newValue }
  }
}
