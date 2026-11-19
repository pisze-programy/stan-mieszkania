import APIClient
import Database
import Dependencies
import DependenciesMacros
import Foundation
import MediaStorage

@DependencyClient
public struct SyncEngineClient: Sendable {
  public var events: @Sendable () async -> AsyncStream<SyncEvent> = {
    AsyncStream { $0.finish() }
  }
  public var processOutbox: @Sendable () async -> SyncOutboxReport = {
    SyncOutboxReport(
      processedCount: 0,
      failedCount: 0,
      deferredCount: 0,
      pausedForForceUpdate: false
    )
  }
  public var enqueueMediaUpload: @Sendable (_ mediaId: String) async throws -> Void
  public var enqueueAllLocalMedia: @Sendable (_ apartmentId: String) async throws -> Int
  public var syncAllOnEntry: @Sendable () async throws -> Int
  public var syncApartment: @Sendable (_ apartmentId: String) async throws -> Int
  public var ensurePhotoCached:
    @Sendable (_ apartmentId: String, _ mediaId: String, _ expectedSha256: String) async throws ->
      String

  public static func live(actor: SyncEngineActor) -> Self {
    Self(
      events: { await actor.events() },
      processOutbox: { await actor.processOutbox() },
      enqueueMediaUpload: { try await actor.enqueueMediaUpload(mediaId: $0) },
      enqueueAllLocalMedia: { try await actor.enqueueAllLocalMedia(apartmentId: $0) },
      syncAllOnEntry: { try await actor.syncAllOnEntry() },
      syncApartment: { try await actor.syncApartment(apartmentId: $0) },
      ensurePhotoCached: {
        try await actor.ensurePhotoCached(
          apartmentId: $0,
          mediaId: $1,
          expectedSha256: $2
        )
      }
    )
  }
}

extension SyncEngineClient: DependencyKey {
  public static var liveValue: SyncEngineClient {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.mediaStorage) var mediaStorage
    @Dependency(\.objectTransfer) var objectTransfer

    let actor = SyncEngineActor(
      database: database,
      apiClient: apiClient,
      mediaStorage: mediaStorage,
      objectTransfer: objectTransfer
    )
    return .live(actor: actor)
  }

  public static var testValue: SyncEngineClient {
    SyncEngineClient()
  }
}

extension DependencyValues {
  public var syncEngine: SyncEngineClient {
    get { self[SyncEngineClient.self] }
    set { self[SyncEngineClient.self] = newValue }
  }
}
