import APIClient
import Database
import Domain
import Foundation
import MediaStorage
import SQLiteData

public actor SyncEngineActor {
  let database: any DatabaseWriter
  let apiClient: APIClient
  let mediaStorage: MediaStorageClient
  let objectTransfer: ObjectTransferClient
  let clock: @Sendable () -> Date
  let broadcaster = SyncEventBroadcaster()
  private var inFlightDownloads: [String: Task<String, any Error>] = [:]

  public init(
    database: any DatabaseWriter,
    apiClient: APIClient,
    mediaStorage: MediaStorageClient,
    objectTransfer: ObjectTransferClient,
    clock: @escaping @Sendable () -> Date = Date.init
  ) {
    self.database = database
    self.apiClient = apiClient
    self.mediaStorage = mediaStorage
    self.objectTransfer = objectTransfer
    self.clock = clock
  }

  public func events() -> AsyncStream<SyncEvent> {
    broadcaster.makeStream()
  }

  // Decision S2-7: Manual single-photo sync queues the photo and its local draft entries.
  public func enqueueMediaUpload(mediaId: String) throws {
    let mediaStore = MediaMutationStore(database: database)
    try mediaStore.queueLocalMediaForCloud(mediaId: mediaId, now: clock())
  }

  // Decision S2-7: Manual batch sync queues every local-only photo in an apartment.
  @discardableResult
  public func enqueueAllLocalMedia(apartmentId: String) throws -> Int {
    let localOnlyState = MediaSyncState.localOnly.rawValue
    let localMediaIds = try database.read { db in
      try MediaRecord
        .where {
          $0.apartmentId.eq(apartmentId)
            && $0.serverReceivedAt.is(nil)
            && $0.syncState.eq(localOnlyState)
        }
        .order { $0.capturedAt.asc() }
        .fetchAll(db)
        .map(\.id)
    }

    let mediaStore = MediaMutationStore(database: database)
    let now = clock()
    for mediaId in localMediaIds {
      try mediaStore.queueLocalMediaForCloud(mediaId: mediaId, now: now)
    }
    return localMediaIds.count
  }

  // Decision S2-10: Lazy download deduplicates concurrent fetches per mediaId and verifies SHA-256.
  public func ensurePhotoCached(
    apartmentId: String,
    mediaId: String,
    expectedSha256: String
  ) async throws -> String {
    if mediaStorage.fileExists(mediaId), let cachedPath = try fetchLocalFilePath(mediaId: mediaId) {
      return cachedPath
    }

    if let existingTask = inFlightDownloads[mediaId] {
      return try await existingTask.value
    }

    let apiClient = self.apiClient
    let objectTransfer = self.objectTransfer
    let mediaStorage = self.mediaStorage
    let downloadTask = Task<String, any Error> {
      let presigned = try await apiClient.getMediaDownloadUrl(apartmentId, mediaId)
      let bytes = try await objectTransfer.downloadJpeg(presigned.url)
      return try mediaStorage.storeRemotePhoto(bytes, expectedSha256, mediaId)
    }
    inFlightDownloads[mediaId] = downloadTask

    do {
      let savedPath = try await downloadTask.value
      inFlightDownloads[mediaId] = nil
      try persistLocalFilePath(mediaId: mediaId, path: savedPath)
      return savedPath
    } catch {
      inFlightDownloads[mediaId] = nil
      throw error
    }
  }

  private func fetchLocalFilePath(mediaId: String) throws -> String? {
    try database.read { db in
      try MediaRecord
        .where { $0.id.eq(mediaId) }
        .fetchOne(db)?
        .localFilePath
    }
  }

  private func persistLocalFilePath(mediaId: String, path: String) throws {
    try database.write { db in
      try MediaRecord
        .where { $0.id.eq(mediaId) }
        .update { $0.localFilePath = #bind(path) }
        .execute(db)
    }
  }
}
