import Foundation
import Synchronization

final class SyncEventBroadcaster: Sendable {
  private let continuations: Mutex<[UUID: AsyncStream<SyncEvent>.Continuation]> = Mutex([:])

  func makeStream() -> AsyncStream<SyncEvent> {
    let id = UUID()
    return AsyncStream { continuation in
      continuations.withLock { $0[id] = continuation }
      continuation.onTermination = { [weak self] _ in
        _ = self?.continuations.withLock { $0.removeValue(forKey: id) }
      }
    }
  }

  func send(_ event: SyncEvent) {
    let snapshot = continuations.withLock { Array($0.values) }
    for continuation in snapshot {
      continuation.yield(event)
    }
  }
}
