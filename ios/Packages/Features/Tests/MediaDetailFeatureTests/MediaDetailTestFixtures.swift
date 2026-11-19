import ComposableArchitecture
import Database
import Domain
import Foundation
import SQLiteData

@testable import MediaDetailFeature

enum MediaDetailTestFixtures {
  static let ownerId = "01933e2a-7b40-7000-8000-000000000001"
  static let contributorId = "01933e2a-7b40-7000-8000-000000000002"
  static let apartmentId = "01933e2a-7b40-7000-8000-000000000010"
  static let mediaId = "01933e2a-7b40-7000-8000-000000000101"
  static let entryOneId = "01933e2a-7b40-7000-8000-000000000201"
  static let entryTwoId = "01933e2a-7b40-7000-8000-000000000202"
  static let entryThreeId = "01933e2a-7b40-7000-8000-000000000203"
  static let markerOneId = "01933e2a-7b40-7000-8000-000000000301"
  static let markerTwoId = "01933e2a-7b40-7000-8000-000000000302"
  static let markerThreeId = "01933e2a-7b40-7000-8000-000000000303"
  static let outboxId = "01933e2a-7b40-7000-8000-000000000401"

  static let width = 1_600
  static let height = 1_200
  static let bytes = 250_000
  static let markerOneCoord = 0.2
  static let markerTwoCoord = 0.6
  static let markerTwoNumber = 2
  static let sha256 = String(repeating: "d", count: ContractConstants.sha256HexLength)

  private static let baseEpoch: TimeInterval = 1_700_000_000
  private static let laterEpoch: TimeInterval = 1_700_003_600
  static let baseDate = Date(timeIntervalSince1970: baseEpoch)
  static let laterDate = Date(timeIntervalSince1970: laterEpoch)

  static let ownerUser = UserProfile(
    id: ownerId,
    displayName: "Jan Kowalski",
    shortTag: "A1B2",
    color: "#007AFF",
    createdAt: baseDate
  )

  static let contributorUser = UserProfile(
    id: contributorId,
    displayName: "Anna Nowak",
    shortTag: "C3D4",
    color: "#34C759",
    createdAt: baseDate
  )

  static func seedDatabase(
    activeRole: MemberRole = .owner,
    isVerifiedMedia: Bool = true
  ) throws -> any DatabaseWriter {
    let database = try makeInMemoryDatabase()
    try ApartmentMutationStore(database: database).saveLocalUser(
      activeRole == .owner ? ownerUser : contributorUser
    )

    let apartment = Apartment(
      id: apartmentId,
      ownerId: ownerId,
      name: "Kawalerka Mokotów",
      street: "Puławska 10",
      city: "Warszawa",
      role: activeRole,
      createdAt: baseDate,
      updatedAt: baseDate
    )
    let members = [
      makeMember(user: ownerUser, role: .owner),
      makeMember(user: contributorUser, role: .contributor),
    ]
    let media = MediaItem(
      id: mediaId,
      apartmentId: apartmentId,
      authorId: ownerId,
      kind: .photo,
      source: .camera,
      sha256: sha256,
      capturedAt: baseDate,
      capturedTz: "Europe/Warsaw",
      capturedAtFromImport: false,
      serverReceivedAt: isVerifiedMedia ? baseDate : nil,
      width: width,
      height: height,
      bytes: bytes,
      syncState: isVerifiedMedia ? .verified : .localOnly,
      localFilePath: "/tmp/\(mediaId).jpg"
    )

    try database.write { db in
      try ApartmentRecord.insert { ApartmentRecord(apartment: apartment) }.execute(db)
      for member in members {
        try MemberRecord.upsert {
          MemberRecord(apartmentId: apartmentId, member: member)
        }.execute(db)
      }
      try MediaRecord.insert { MediaRecord(item: media) }.execute(db)
      try seedInitialEntries(isVerifiedMedia: isVerifiedMedia, in: db)
    }
    return database
  }

  static func makeIDGenerator(_ values: [String]) -> any IDGenerator {
    let queue = LockIsolated(values)
    return ClosureIDGenerator {
      queue.withValue { items in
        items.isEmpty ? UUIDv7.generateNow() : items.removeFirst()
      }
    }
  }

  private static func makeMember(user: UserProfile, role: MemberRole) -> ApartmentMember {
    ApartmentMember(
      userId: user.id,
      displayName: user.displayName,
      shortTag: user.shortTag,
      color: user.color,
      role: role,
      joinedAt: baseDate
    )
  }

  private static func seedInitialEntries(isVerifiedMedia: Bool, in db: Database) throws {
    let entryOne = EntryItem(
      id: entryOneId,
      mediaId: mediaId,
      authorId: ownerId,
      text: "Rysa na drzwiach [1]",
      markers: [],
      createdAt: baseDate,
      serverReceivedAt: isVerifiedMedia ? baseDate : nil
    )
    let markerOne = MarkerPoint(
      id: markerOneId,
      entryId: entryOneId,
      mediaId: mediaId,
      number: 1,
      isServerAssigned: isVerifiedMedia,
      x: markerOneCoord,
      y: markerOneCoord
    )
    try EntryRecord.insert { EntryRecord(item: entryOne) }.execute(db)
    try MarkerRecord.insert { MarkerRecord(marker: markerOne) }.execute(db)

    guard isVerifiedMedia else {
      return
    }
    let entryTwo = EntryItem(
      id: entryTwoId,
      mediaId: mediaId,
      authorId: contributorId,
      text: "Odprysk farby [2]",
      markers: [],
      createdAt: laterDate,
      serverReceivedAt: laterDate
    )
    let markerTwo = MarkerPoint(
      id: markerTwoId,
      entryId: entryTwoId,
      mediaId: mediaId,
      number: markerTwoNumber,
      isServerAssigned: true,
      x: markerTwoCoord,
      y: markerTwoCoord
    )
    try EntryRecord.insert { EntryRecord(item: entryTwo) }.execute(db)
    try MarkerRecord.insert { MarkerRecord(marker: markerTwo) }.execute(db)
  }
}
