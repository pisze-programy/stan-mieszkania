import Dependencies
import Domain

enum IDGeneratorKey: DependencyKey {
  static let liveValue: any IDGenerator = SystemIDGenerator()
  static let testValue: any IDGenerator = SystemIDGenerator()
}

extension DependencyValues {
  var idGenerator: any IDGenerator {
    get { self[IDGeneratorKey.self] }
    set { self[IDGeneratorKey.self] = newValue }
  }
}
