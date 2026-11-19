import APIClient
import Database
import Domain
import Foundation
import MediaStorage
import SQLiteData
import SyncEngine
import Testing

@Suite("SyncEngine Quota Exceeded and 426 Pause Tests")
struct OutboxQuotaAndPauseTests {
  @Test("Reverts media to localOnly on QUOTA_EXCEEDED preserving file & entry and emits event")
  func quotaExceededRevertsToLocalOnlyAndEmitsEvent() async throws {
    let tempDir = SyncEngineTestFixtures.makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let database = try makeInMemoryDatabase()
    let mediaStorage = MediaStorageClient.live(baseDirectory: tempDir)
    let cachedPath = try mediaStorage.storeRemotePhoto(
      SyncEngineTestFixtures.sampleJpegBytes,
      SyncEngineTestFixtures.sampleJpegSha256,
      SyncEngineTestFixtures.mediaOneId
    )
    try seedQueuedMediaOnly(in: database, localFilePath: cachedPath)

    let actor = makeQuotaExceededActor(database: database, mediaStorage: mediaStorage)
    let stream = await actor.events()
    let collector = collectEventsUntilCompletion(stream)
    let report = await actor.processOutbox()
    let events = await collector.value

    #expect(report.failedCount == 1)
    #expect(
      events.contains(
        .quotaExceeded(
          apartmentId: SyncEngineTestFixtures.apartmentId,
          mediaId: SyncEngineTestFixtures.mediaOneId
        )
      )
    )

    let media = try await #require(
      database.read {
        try MediaRecord.where { $0.id.eq(SyncEngineTestFixtures.mediaOneId) }.fetchOne($0)
      }
    )
    #expect(media.syncState == MediaSyncState.localOnly.rawValue)
    #expect(media.serverReceivedAt == nil)
    #expect(mediaStorage.fileExists(SyncEngineTestFixtures.mediaOneId))
    let entryCount = try await database.read { try EntryRecord.fetchAll($0).count }
    #expect(entryCount == 1)
    #expect(try OutboxRepository(database: database).fetchAllOperations().isEmpty)
  }

  @Test("Pauses outbox on 426 APP_UPDATE_REQUIRED without deleting pending operations")
  func pausesOutboxOnUpgradeRequiredPreservingQueue() async throws {
    let database = try makeInMemoryDatabase()
    let aptStore = ApartmentMutationStore(database: database)
    try aptStore.createApartment(
      SyncEngineTestFixtures.makeApartment(),
      creator: SyncEngineTestFixtures.makeOwnerMember(),
      outboxId: SyncEngineTestFixtures.outboxAptId,
      now: SyncEngineTestFixtures.baseDate
    )

    var apiClient = APIClient()
    apiClient.putApartment = { _ in
      throw APIProblemError(
        status: SyncEngineTestFixtures.statusUpgradeRequired,
        code: .known(.appUpdateRequired),
        title: "Update required",
        detail: "Upgrade client"
      )
    }

    let actor = SyncEngineActor(
      database: database,
      apiClient: apiClient,
      mediaStorage: MediaStorageClient(),
      objectTransfer: ObjectTransferClient(),
      clock: { SyncEngineTestFixtures.confirmedDate }
    )
    let report = await actor.processOutbox()
    #expect(report.pausedForForceUpdate)

    let remaining = try OutboxRepository(database: database).fetchAllOperations()
    #expect(remaining.count == 1)
    #expect(remaining.first?.status == OutboxOperationStatus.pending.rawValue)
  }

  private func makeQuotaExceededActor(
    database: any DatabaseWriter,
    mediaStorage: MediaStorageClient
  ) -> SyncEngineActor {
    var apiClient = APIClient()
    apiClient.initMediaUpload = { _ in
      throw APIProblemError(
        status: SyncEngineTestFixtures.statusConflict,
        code: .known(.quotaExceeded),
        title: "Quota exceeded",
        detail: "250 limit reached"
      )
    }
    return SyncEngineActor(
      database: database,
      apiClient: apiClient,
      mediaStorage: mediaStorage,
      objectTransfer: ObjectTransferClient(),
      clock: { SyncEngineTestFixtures.confirmedDate }
    )
  }

  private func collectEventsUntilCompletion(
    _ stream: AsyncStream<SyncEvent>
  ) -> Task<[SyncEvent], Never> {
    Task {
      var captured: [SyncEvent] = []
      for await event in stream {
        captured.append(event)
        if event == .outboxCompleted {
          break
        }
      }
      return captured
    }
  }

  private func seedQueuedMediaOnly(
    in database: any DatabaseWriter,
    localFilePath: String
  ) throws {
    try database.write { db in
      let apartment = ApartmentRecord(apartment: SyncEngineTestFixtures.makeApartment())
      try ApartmentRecord.insert { apartment }.execute(db)
    }
    let mediaStore = MediaMutationStore(database: database)
    try mediaStore.saveLocalMedia(
      SyncEngineTestFixtures.makeMediaItem(localFilePath: localFilePath),
      initialEntry: SyncEngineTestFixtures.makeDraftEntry(),
      queueForCloud: true,
      mediaOutboxId: SyncEngineTestFixtures.outboxMediaId,
      entryOutboxId: SyncEngineTestFixtures.outboxEntryId,
      now: SyncEngineTestFixtures.baseDate
    )
  }
}
