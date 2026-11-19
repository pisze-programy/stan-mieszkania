import APIClient
import Database
import Domain
import Foundation
import MediaStorage
import SQLiteData
import SyncEngine
import Synchronization
import Testing

@Suite("SyncEngine Outbox Upload and Marker Renumbering Tests")
struct OutboxUploadAndRenumberingTests {
  @Test("Processes apartment -> media upload -> confirm -> entry with [1] -> [3] renumbering")
  func fullLocalToCloudPipelineWithRenumbering() async throws {
    let tempDir = SyncEngineTestFixtures.makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let database = try makeInMemoryDatabase()
    let mediaStorage = MediaStorageClient.live(baseDirectory: tempDir)
    let cachedPath = try mediaStorage.storeRemotePhoto(
      SyncEngineTestFixtures.sampleJpegBytes,
      SyncEngineTestFixtures.sampleJpegSha256,
      SyncEngineTestFixtures.mediaOneId
    )
    try seedQueuedApartmentMediaAndEntry(in: database, localFilePath: cachedPath)

    let steps = LockedBox<[String]>([])
    let actor = try makeUploadActor(
      database: database,
      mediaStorage: mediaStorage,
      steps: steps
    )
    let report = await actor.processOutbox()

    #expect(report.processedCount == SyncEngineTestFixtures.expectedProcessedThree)
    #expect(report.failedCount == 0)
    #expect(!report.pausedForForceUpdate)
    #expect(
      steps.withValue { $0 }
        == ["putApartment", "initMedia", "putBytes", "confirmMedia", "putEntry"]
    )
    try assertMediaAndRenumberedEntrySynced(in: database)
  }

  @Test("Persists server-trimmed confirmedEntry.text verbatim during entry confirmation")
  func persistsServerTrimmedEntryTextVerbatim() async throws {
    let database = try makeInMemoryDatabase()
    try await seedConfirmedMediaWithUntrimmedEntry(in: database)

    var apiClient = APIClient()
    apiClient.putMediaEntry = { _ in
      EntryItem(
        id: SyncEngineTestFixtures.entryId,
        mediaId: SyncEngineTestFixtures.mediaOneId,
        authorId: SyncEngineTestFixtures.ownerId,
        text: "Rysa z bialymi znakami",
        createdAt: SyncEngineTestFixtures.baseDate,
        serverReceivedAt: SyncEngineTestFixtures.confirmedDate
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
    #expect(report.processedCount == 1)

    let persisted = try await #require(
      database.read {
        try EntryRecord.where { $0.id.eq(SyncEngineTestFixtures.entryId) }.fetchOne($0)
      }
    )
    #expect(persisted.text == "Rysa z bialymi znakami")
  }

  private func seedConfirmedMediaWithUntrimmedEntry(in database: any DatabaseWriter) async throws {
    try await database.write { db in
      let apt = ApartmentRecord(apartment: SyncEngineTestFixtures.makeApartment())
      try ApartmentRecord.insert { apt }.execute(db)
    }
    let mediaStore = MediaMutationStore(database: database)
    try mediaStore.saveLocalMedia(
      SyncEngineTestFixtures.makeMediaItem(id: SyncEngineTestFixtures.mediaOneId),
      queueForCloud: false,
      now: SyncEngineTestFixtures.baseDate
    )
    try mediaStore.confirmMediaUploaded(
      mediaId: SyncEngineTestFixtures.mediaOneId,
      serverReceivedAt: SyncEngineTestFixtures.baseDate
    )
    let untrimmed = EntryItem(
      id: SyncEngineTestFixtures.entryId,
      mediaId: SyncEngineTestFixtures.mediaOneId,
      authorId: SyncEngineTestFixtures.ownerId,
      text: "   Rysa z bialymi znakami   ",
      createdAt: SyncEngineTestFixtures.baseDate
    )
    try EntryMutationStore(database: database).createEntry(
      untrimmed,
      queueForCloud: true,
      outboxId: SyncEngineTestFixtures.outboxEntryId,
      now: SyncEngineTestFixtures.baseDate
    )
  }

  private func assertMediaAndRenumberedEntrySynced(in database: any DatabaseWriter) throws {
    let syncedMedia = try #require(
      database.read {
        try MediaRecord.where { $0.id.eq(SyncEngineTestFixtures.mediaOneId) }.fetchOne($0)
      }
    )
    #expect(syncedMedia.syncState == MediaSyncState.verified.rawValue)
    #expect(syncedMedia.serverReceivedAt == SyncEngineTestFixtures.confirmedDate)

    let syncedEntry = try #require(
      database.read {
        try EntryRecord.where { $0.id.eq(SyncEngineTestFixtures.entryId) }.fetchOne($0)
      }
    )
    #expect(syncedEntry.text == "Uszkodzenie sciany [3]")
    #expect(syncedEntry.serverReceivedAt == SyncEngineTestFixtures.confirmedDate)

    let syncedMarker = try #require(database.read { try MarkerRecord.fetchOne($0) })
    #expect(syncedMarker.number == SyncEngineTestFixtures.markerServerThree)
    #expect(syncedMarker.isServerAssigned)
    #expect(try OutboxRepository(database: database).fetchAllOperations().isEmpty)
  }

  private func makeUploadActor(
    database: any DatabaseWriter,
    mediaStorage: MediaStorageClient,
    steps: LockedBox<[String]>
  ) throws -> SyncEngineActor {
    let presignedURL = try #require(URL(string: "https://r2.stanmieszkania.local/put/photo-1"))
    var apiClient = APIClient()
    apiClient.putApartment = { _ in
      steps.withValue { $0.append("putApartment") }
      return SyncEngineTestFixtures.makeApartment()
    }
    apiClient.initMediaUpload = { _ in
      steps.withValue { $0.append("initMedia") }
      return InitMediaUploadResult(
        media: SyncEngineTestFixtures.makeMediaItem(syncState: .queued),
        upload: PresignedURLInfo(url: presignedURL, expiresAt: SyncEngineTestFixtures.confirmedDate)
      )
    }
    apiClient.confirmMediaUpload = { _, _ in
      steps.withValue { $0.append("confirmMedia") }
      return SyncEngineTestFixtures.makeMediaItem(
        syncState: .verified,
        serverReceivedAt: SyncEngineTestFixtures.confirmedDate
      )
    }
    apiClient.putMediaEntry = { _ in
      steps.withValue { $0.append("putEntry") }
      return SyncEngineTestFixtures.makeConfirmedEntry()
    }
    let transfer = ObjectTransferClient(
      uploadJpeg: { _, _, onProgress in
        steps.withValue { $0.append("putBytes") }
        onProgress(SyncEngineTestFixtures.progressHalf)
      },
      downloadJpeg: { _ in SyncEngineTestFixtures.sampleJpegBytes }
    )
    return SyncEngineActor(
      database: database,
      apiClient: apiClient,
      mediaStorage: mediaStorage,
      objectTransfer: transfer,
      clock: { SyncEngineTestFixtures.confirmedDate }
    )
  }

  private func seedQueuedApartmentMediaAndEntry(
    in database: any DatabaseWriter,
    localFilePath: String
  ) throws {
    let aptStore = ApartmentMutationStore(database: database)
    try aptStore.createApartment(
      SyncEngineTestFixtures.makeApartment(inviteCode: nil),
      creator: SyncEngineTestFixtures.makeOwnerMember(),
      outboxId: SyncEngineTestFixtures.outboxAptId,
      now: SyncEngineTestFixtures.baseDate
    )
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
