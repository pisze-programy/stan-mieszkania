import APIClient
import Database
import Domain
import Foundation
import MediaStorage
import SQLiteData
import SyncEngine
import Synchronization
import Testing

@Suite("SyncEngine Manual Sync, Multi-Page Pull, and Lazy Download Tests")
struct ManualSyncPullAndCacheTests {
  @Test("enqueueAllLocalMedia queues only local-only photos and their draft entries")
  func enqueueAllLocalMediaBatchesOfflinePhotos() async throws {
    let database = try makeInMemoryDatabase()
    try await database.write { db in
      let apartment = ApartmentRecord(apartment: SyncEngineTestFixtures.makeApartment())
      try ApartmentRecord.insert { apartment }.execute(db)
    }

    let mediaStore = MediaMutationStore(database: database)
    try mediaStore.saveLocalMedia(
      SyncEngineTestFixtures.makeMediaItem(id: SyncEngineTestFixtures.mediaOneId),
      initialEntry: SyncEngineTestFixtures.makeDraftEntry(),
      queueForCloud: false,
      now: SyncEngineTestFixtures.baseDate
    )
    try mediaStore.saveLocalMedia(
      SyncEngineTestFixtures.makeMediaItem(id: SyncEngineTestFixtures.mediaTwoId),
      queueForCloud: false,
      now: SyncEngineTestFixtures.baseDate
    )

    let actor = SyncEngineActor(
      database: database,
      apiClient: APIClient(),
      mediaStorage: MediaStorageClient(),
      objectTransfer: ObjectTransferClient(),
      clock: { SyncEngineTestFixtures.baseDate }
    )
    let queuedCount = try await actor.enqueueAllLocalMedia(
      apartmentId: SyncEngineTestFixtures.apartmentId
    )
    #expect(queuedCount == SyncEngineTestFixtures.expectedCountTwo)
    #expect(
      try OutboxRepository(database: database).fetchAllOperations().count
        == SyncEngineTestFixtures.expectedProcessedThree
    )
    #expect(
      try await actor.enqueueAllLocalMedia(apartmentId: SyncEngineTestFixtures.apartmentId) == 0
    )
  }

  @Test("Pulls multi-page change feed until hasMore == false and advances sync cursor")
  func pullsMultiPageChangeFeedExhaustively() async throws {
    let database = try makeInMemoryDatabase()
    let requestedCursors = Mutex<[Int]>([])

    var apiClient = APIClient()
    apiClient.listApartmentChanges = { _, after, _ in
      let cursor = after ?? 0
      requestedCursors.withLock { $0.append(cursor) }
      return cursor == 0
        ? SyncEngineTestFixtures.makeApartmentChangePage()
        : SyncEngineTestFixtures.makeMediaChangePage()
    }

    let actor = SyncEngineActor(
      database: database,
      apiClient: apiClient,
      mediaStorage: MediaStorageClient(),
      objectTransfer: ObjectTransferClient(),
      clock: { SyncEngineTestFixtures.confirmedDate }
    )
    let applied = try await actor.syncApartment(apartmentId: SyncEngineTestFixtures.apartmentId)

    #expect(applied == SyncEngineTestFixtures.expectedCountTwo)
    #expect(requestedCursors.withLock { $0 } == [0, SyncEngineTestFixtures.seqOne])
    #expect(
      try SyncDeltaApplier(database: database).fetchLastSeq(
        apartmentId: SyncEngineTestFixtures.apartmentId
      ) == SyncEngineTestFixtures.seqTwo
    )
    let mediaCount = try await database.read { try MediaRecord.fetchCount($0) }
    #expect(mediaCount == 1)
  }

  @Test("Deduplicates concurrent ensurePhotoCached downloads and verifies SHA-256")
  func deduplicatesConcurrentDownloadsAndVerifiesSha256() async throws {
    let tempDir = SyncEngineTestFixtures.makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let database = try makeInMemoryDatabase()
    try seedVerifiedMedia(in: database)

    let downloadCalls = LockedBox<Int>(0)
    let actor = try makeDownloadActor(
      database: database,
      tempDir: tempDir,
      downloadCalls: downloadCalls
    )

    async let first = actor.ensurePhotoCached(
      apartmentId: SyncEngineTestFixtures.apartmentId,
      mediaId: SyncEngineTestFixtures.mediaOneId,
      expectedSha256: SyncEngineTestFixtures.sampleJpegSha256
    )
    async let second = actor.ensurePhotoCached(
      apartmentId: SyncEngineTestFixtures.apartmentId,
      mediaId: SyncEngineTestFixtures.mediaOneId,
      expectedSha256: SyncEngineTestFixtures.sampleJpegSha256
    )
    let (firstPath, secondPath) = try await (first, second)
    #expect(firstPath == secondPath)
    #expect(downloadCalls.withValue { $0 } == 1)

    let cachedAgain = try await actor.ensurePhotoCached(
      apartmentId: SyncEngineTestFixtures.apartmentId,
      mediaId: SyncEngineTestFixtures.mediaOneId,
      expectedSha256: SyncEngineTestFixtures.sampleJpegSha256
    )
    #expect(cachedAgain == firstPath)
    #expect(downloadCalls.withValue { $0 } == 1)
  }

  @Test("Bounds exponential retry backoff delay cleanly")
  func boundsExponentialBackoffDelay() {
    #expect(
      SyncBackoffPolicy.delaySeconds(forAttemptCount: 0) == SyncEngineConstants.baseBackoffSeconds
    )
    #expect(
      SyncBackoffPolicy.delaySeconds(forAttemptCount: SyncEngineTestFixtures.attemptThree)
        == SyncEngineTestFixtures.expectedDelayAttemptThree
    )
    #expect(
      SyncBackoffPolicy.delaySeconds(forAttemptCount: SyncEngineTestFixtures.attemptLarge)
        == SyncEngineConstants.maxBackoffSeconds
    )
  }

  private func seedVerifiedMedia(in database: any DatabaseWriter) throws {
    try database.write { db in
      let apartment = ApartmentRecord(apartment: SyncEngineTestFixtures.makeApartment())
      let media = MediaRecord(
        item: SyncEngineTestFixtures.makeMediaItem(
          syncState: .verified,
          serverReceivedAt: SyncEngineTestFixtures.confirmedDate
        )
      )
      try ApartmentRecord.insert { apartment }.execute(db)
      try MediaRecord.insert { media }.execute(db)
    }
  }

  private func makeDownloadActor(
    database: any DatabaseWriter,
    tempDir: URL,
    downloadCalls: LockedBox<Int>
  ) throws -> SyncEngineActor {
    let downloadURL = try #require(URL(string: "https://r2.stanmieszkania.local/get/photo-1"))
    var apiClient = APIClient()
    apiClient.getMediaDownloadUrl = { _, _ in
      PresignedURLInfo(url: downloadURL, expiresAt: SyncEngineTestFixtures.confirmedDate)
    }
    let transfer = ObjectTransferClient(
      uploadJpeg: { _, _, _ in },
      downloadJpeg: { _ in
        downloadCalls.withValue { $0 += 1 }
        try await Task.sleep(nanoseconds: SyncEngineTestFixtures.downloadDelayNanos)
        return SyncEngineTestFixtures.sampleJpegBytes
      }
    )
    return SyncEngineActor(
      database: database,
      apiClient: apiClient,
      mediaStorage: MediaStorageClient.live(baseDirectory: tempDir),
      objectTransfer: transfer
    )
  }
}
