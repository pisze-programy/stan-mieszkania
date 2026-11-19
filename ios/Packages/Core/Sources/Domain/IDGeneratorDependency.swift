import Dependencies
import Foundation

private struct UnimplementedIDGenerator: IDGenerator, Sendable {
  func generate() -> String {
    reportIssue("Unimplemented: 'DependencyValues.idGenerator'")
    return UUIDv7.generateNow()
  }
}

public enum IDGeneratorKey: DependencyKey {
  public static let liveValue: any IDGenerator = SystemIDGenerator()
  public static let previewValue: any IDGenerator = SystemIDGenerator()
  public static let testValue: any IDGenerator = UnimplementedIDGenerator()
}

extension DependencyValues {
  public var idGenerator: any IDGenerator {
    get { self[IDGeneratorKey.self] }
    set { self[IDGeneratorKey.self] = newValue }
  }
}
