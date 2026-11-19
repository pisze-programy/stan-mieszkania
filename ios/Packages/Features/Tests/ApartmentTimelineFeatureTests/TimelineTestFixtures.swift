import Database
import Domain
import Foundation
import SQLiteData
import Synchronization

@testable import ApartmentTimelineFeature

enum TimelineTestFixtures {
  static let ownerId = "01933e2a-7b40-7000-8000-000000000001"
  static let contributorId = "01933e2a-7b40-7000-8000-000000000002"
  static let apartmentId = "01933e2a-7b40-7000-8000-000000000010"
  static let otherApartmentId = "01933e2a-7b40-7000-8000-000000000011"
  static let mediaLocalId = "01933e2a-7b40-7000-8000-000000000101"
  static let mediaVerifiedId = "01933e2a-7b40-7000-8000-000000000102"
  static let mediaTombstoneId = "01933e2a-7b40-7000-8000-000000000103"
  static let outboxId = "01933e2a-7b40-7000-8000-000000000201"
  static let changeId = "01933e2a-7b40-7000-8000-000000000301"

  static let width = 1_200
  static let height = 900
  static let bytes = 180_000
  static let defaultCloudMediaCount = 2
  static let sha256 = String(repeating: "a", count: ContractConstants.sha256HexLength)
  static let warsawTimeZone = TimeZone(identifier: "Europe/Warsaw") ?? .gmt

  private static let thursdayEpoch: TimeInterval = 1_668_682_800
  private static let wednesdayEpoch: TimeInterval = 1_668_589_200
  private static let thursdayLaterEpoch: TimeInterval = 1_668_690_000

  static let thursdayDate = Date(timeIntervalSince1970: thursdayEpoch)
  static let wednesdayDate = Date(timeIntervalSince1970: wednesdayEpoch)
  static let thursdayLaterDate = Date(timeIntervalSince1970: thursdayLaterEpoch)

  static var warsawCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = warsawTimeZone
    return calendar
  }

  static let ownerUser = UserProfile(
    id: ownerId,
    displayName: "Jan Kowalski",
    shortTag: "A1B2",
    color: "#007AFF",
    createdAt: wednesdayDate
  )

  static let contributorUser = UserProfile(
    id: contributorId,
    displayName: "Anna Nowak",
    shortTag: "C3D4",
    color: "#34C759",
    createdAt: wednesdayDate
  )

  static func makeApartment(
    role: MemberRole = .owner,
    shouldSuggestInviteCodeReset: Bool = false,
    cloudMediaCount: Int = defaultCloudMediaCount
  ) -> Apartment {
    Apartment(
      id: apartmentId,
      ownerId: ownerId,
      name: "Kawalerka Mokotów",
      street: "Puławska 10",
      city: "Warszawa",
      role: role,
      inviteCode: role == .owner ? "K7QM-4XPB" : nil,
      shouldSuggestInviteCodeReset: shouldSuggestInviteCodeReset,
      cloudMediaCount: cloudMediaCount,
      createdAt: wednesdayDate,
      updatedAt: wednesdayDate
    )
  }

  static func seedTimelineDatabase(
    role: MemberRole = .owner,
    shouldSuggestInviteCodeReset: Bool = false
  ) throws -> any DatabaseWriter {
    let database = try makeInMemoryDatabase()
    let apartmentStore = ApartmentMutationStore(database: database)
    try apartmentStore.saveLocalUser(role == .owner ? ownerUser : contributorUser)

    let apartment = makeApartment(
      role: role,
      shouldSuggestInviteCodeReset: shouldSuggestInviteCodeReset
    )
    let members = [
      makeMember(user: ownerUser, role: .owner),
      makeMember(user: contributorUser, role: .contributor),
    ]

    try database.write { db in
      try ApartmentRecord.insert { ApartmentRecord(apartment: apartment) }.execute(db)
      for member in members {
        try MemberRecord.upsert {
          MemberRecord(apartmentId: apartment.id, member: member)
        }.execute(db)
      }
      try SyncCursorRecord.upsert {
        SyncCursorRecord(apartmentId: apartment.id, updatedAt: wednesdayDate)
      }.execute(db)
    }

    try seedTimelineMedia(in: database)
    return database
  }

  private static func makeMember(user: UserProfile, role: MemberRole) -> ApartmentMember {
    ApartmentMember(
      userId: user.id,
      displayName: user.displayName,
      shortTag: user.shortTag,
      color: user.color,
      role: role,
      joinedAt: wednesdayDate
    )
  }

  private static func seedTimelineMedia(in database: any DatabaseWriter) throws {
    let mediaStore = MediaMutationStore(database: database)
    let local = makePhoto(
      id: mediaLocalId,
      authorId: ownerId,
      source: .camera,
      capturedAt: thursdayLaterDate,
      syncState: .localOnly
    )
    let verified = makePhoto(
      id: mediaVerifiedId,
      authorId: contributorId,
      source: .imported,
      capturedAt: thursdayDate,
      serverReceivedAt: thursdayDate,
      syncState: .verified
    )
    let tombstone = makePhoto(
      id: mediaTombstoneId,
      authorId: ownerId,
      source: .camera,
      capturedAt: wednesdayDate,
      serverReceivedAt: wednesdayDate,
      syncState: .softDeleted,
      deletedAt: thursdayDate,
      deletedBy: ownerId
    )
    try mediaStore.saveLocalMedia(local, queueForCloud: false, now: thursdayLaterDate)
    try database.write { db in
      try MediaRecord.insert { MediaRecord(item: verified) }.execute(db)
      try MediaRecord.insert { MediaRecord(item: tombstone) }.execute(db)
    }
  }

  private static func makePhoto(
    id: String,
    authorId: String,
    source: MediaSource,
    capturedAt: Date,
    serverReceivedAt: Date? = nil,
    syncState: MediaSyncState,
    deletedAt: Date? = nil,
    deletedBy: String? = nil
  ) -> MediaItem {
    MediaItem(
      id: id,
      apartmentId: apartmentId,
      authorId: authorId,
      kind: .photo,
      source: source,
      sha256: sha256,
      capturedAt: capturedAt,
      capturedTz: "Europe/Warsaw",
      capturedAtFromImport: false,
      serverReceivedAt: serverReceivedAt,
      width: width,
      height: height,
      bytes: bytes,
      syncState: syncState,
      deletedAt: deletedAt,
      deletedBy: deletedBy
    )
  }
}

final class SequenceIDGenerator: IDGenerator, Sendable {
  private let values: [String]
  private let index = Mutex<Int>(0)

  init(values: [String]) { self.values = values }

  func generate() -> String {
    index.withLock { current in
      let position = current
      current += 1
      return position < values.count ? values[position] : UUIDv7.generateNow()
    }
  }
}
