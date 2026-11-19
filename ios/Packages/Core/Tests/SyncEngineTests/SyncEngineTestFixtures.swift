import APIClient
import Database
import Domain
import Foundation
import MediaStorage
import SyncEngine
import Synchronization

final class LockedBox<Value: Sendable>: Sendable {
  private let storage: Mutex<Value>

  init(_ value: Value) {
    self.storage = Mutex(value)
  }

  func withValue<Result: Sendable>(_ body: (inout Value) -> Result) -> Result {
    storage.withLock { value in
      body(&value)
    }
  }
}

enum SyncEngineTestFixtures {
  static let ownerId = "01933e2a-7b40-7000-8000-000000000001"
  static let apartmentId = "01933e2a-7b40-7000-8000-000000000010"
  static let mediaOneId = "01933e2a-7b40-7000-8000-000000000020"
  static let mediaTwoId = "01933e2a-7b40-7000-8000-000000000021"
  static let entryId = "01933e2a-7b40-7000-8000-000000000030"
  static let markerId = "01933e2a-7b40-7000-8000-000000000040"
  static let outboxAptId = "01933e2a-7b40-7000-8000-000000000050"
  static let outboxMediaId = "01933e2a-7b40-7000-8000-000000000051"
  static let outboxEntryId = "01933e2a-7b40-7000-8000-000000000052"

  static let baseEpoch: TimeInterval = 1_730_000_000
  static let confirmedEpoch: TimeInterval = 1_730_000_120
  static let baseDate = Date(timeIntervalSince1970: baseEpoch)
  static let confirmedDate = Date(timeIntervalSince1970: confirmedEpoch)
  static let width = 1_200
  static let height = 900
  static let markerLocalOne = 1
  static let markerServerThree = 3
  static let coordX = 0.25
  static let coordY = 0.75
  static let statusConflict = 409
  static let statusUpgradeRequired = 426
  static let seqOne = 1
  static let seqTwo = 2
  static let expectedCountTwo = 2
  static let expectedProcessedThree = 3
  static let progressHalf: Double = 0.5
  static let attemptThree = 3
  static let attemptLarge = 20
  static let expectedDelayAttemptThree: TimeInterval = 40
  static let downloadDelayNanos: UInt64 = 30_000_000

  static let sampleJpegBytes = Data("synthetic-jpeg-payload-for-sync-engine".utf8)
  static var sampleJpegSha256: String {
    SHA256Hasher.hexDigest(of: sampleJpegBytes)
  }

  static func makeTempDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
  }

  static func makeOwnerMember() -> ApartmentMember {
    ApartmentMember(
      userId: ownerId, displayName: "Anna Nowak", shortTag: "A1B2",
      color: "#007AFF", role: .owner, joinedAt: baseDate
    )
  }

  static func makeOwnerSummary() -> AuthorSummary {
    AuthorSummary(
      userId: ownerId, displayName: "Anna Nowak", shortTag: "A1B2",
      color: "#007AFF", role: .owner
    )
  }

  static func makeApartment(inviteCode: String? = "K7QM4XPB") -> Apartment {
    Apartment(
      id: apartmentId,
      ownerId: ownerId,
      name: "Mieszkanie Mokotow",
      street: "Pulawska 10",
      city: "Warszawa",
      role: .owner,
      inviteCode: inviteCode,
      shouldSuggestInviteCodeReset: false,
      cloudMediaCount: 0,
      createdAt: baseDate,
      updatedAt: baseDate
    )
  }

  static func makeMediaItem(
    id: String = mediaOneId,
    localFilePath: String? = nil,
    syncState: MediaSyncState = .localOnly,
    serverReceivedAt: Date? = nil
  ) -> MediaItem {
    MediaItem(
      id: id,
      apartmentId: apartmentId,
      authorId: ownerId,
      kind: .photo,
      source: .camera,
      sha256: sampleJpegSha256,
      capturedAt: baseDate,
      capturedTz: "Europe/Warsaw",
      capturedAtFromImport: false,
      serverReceivedAt: serverReceivedAt,
      width: width,
      height: height,
      bytes: sampleJpegBytes.count,
      syncState: syncState,
      localFilePath: localFilePath
    )
  }

  static func makeDraftEntry() -> EntryItem {
    let marker = MarkerPoint(
      id: markerId,
      entryId: entryId,
      mediaId: mediaOneId,
      number: markerLocalOne,
      isServerAssigned: false,
      x: coordX,
      y: coordY
    )
    return EntryItem(
      id: entryId,
      mediaId: mediaOneId,
      authorId: ownerId,
      text: "Uszkodzenie sciany [1]",
      markers: [marker],
      createdAt: baseDate
    )
  }

  static func makeConfirmedEntry() -> EntryItem {
    let marker = MarkerPoint(
      id: markerId,
      entryId: entryId,
      mediaId: mediaOneId,
      number: markerServerThree,
      isServerAssigned: true,
      x: coordX,
      y: coordY
    )
    return EntryItem(
      id: entryId,
      mediaId: mediaOneId,
      authorId: ownerId,
      text: "Uszkodzenie sciany [3]",
      markers: [marker],
      createdAt: baseDate,
      serverReceivedAt: confirmedDate
    )
  }

  static func makeApartmentChangePage() -> APISyncChangesPage {
    let change = APIHydratedSyncChange(
      seq: seqOne,
      apartmentId: apartmentId,
      entityType: DatabaseConstants.SyncEntityType.apartment,
      entityId: apartmentId,
      op: "created",
      createdAt: baseDate,
      payload: .apartment(makeApartment())
    )
    return APISyncChangesPage(changes: [change], nextSeq: seqOne, hasMore: true)
  }

  static func makeMediaChangePage() -> APISyncChangesPage {
    let snapshot = APISyncMediaSnapshot(
      media: makeMediaItem(syncState: .verified, serverReceivedAt: confirmedDate),
      uploadStatus: .uploaded,
      author: makeOwnerSummary()
    )
    let change = APIHydratedSyncChange(
      seq: seqTwo,
      apartmentId: apartmentId,
      entityType: DatabaseConstants.SyncEntityType.media,
      entityId: mediaOneId,
      op: "confirmed",
      createdAt: confirmedDate,
      payload: .media(snapshot)
    )
    return APISyncChangesPage(changes: [change], nextSeq: seqTwo, hasMore: false)
  }
}
