import AuthClient
import Database
import Domain
import Foundation
import SQLiteData

struct ProfileTableCounts: Equatable {
  let users: Int
  let apartments: Int
  let members: Int
  let media: Int
  let outbox: Int

  static let empty = Self(users: 0, apartments: 0, members: 0, media: 0, outbox: 0)
  static let seeded = Self(users: 1, apartments: 1, members: 1, media: 1, outbox: 1)
}

enum ProfileTestFixtures {
  static let userId = "01933e2a-7b40-7000-8000-000000000010"
  static let apartmentId = "01933e2a-7b40-7000-8000-000000000011"
  static let mediaId = "01933e2a-7b40-7000-8000-000000000012"
  static let outboxId = "01933e2a-7b40-7000-8000-000000000013"
  static let baseTimestamp: TimeInterval = 1_700_000_000
  static let baseDate = Date(timeIntervalSince1970: baseTimestamp)
  static let width = 1_200
  static let height = 900
  static let bytes = 240_000
  static let httpStatusInternalError = 500
  static let sha256 = String(repeating: "b", count: ContractConstants.sha256HexLength)
  static let appleSession = AuthSession(
    firebaseUid: "apple-uid-1",
    displayName: "Jan Kowalski",
    bearerToken: "eyJhbGciOiJSUzI1NiJ9.token"
  )
  static let localDevSession = AuthSession(
    firebaseUid: "dev-uid-1",
    displayName: "Jan Kowalski",
    bearerToken: "dev:dev-uid-1"
  )
  static let initialUser = UserProfile(
    id: userId,
    displayName: "Jan Kowalski",
    shortTag: "A1B2",
    color: DomainConstants.defaultAuthorColor,
    createdAt: baseDate
  )
  static let updatedUser = UserProfile(
    id: userId,
    displayName: "Anna Nowak",
    shortTag: "A1B2",
    color: DomainConstants.defaultAuthorColor,
    createdAt: baseDate
  )
  static let apartment = Apartment(
    id: apartmentId,
    ownerId: userId,
    name: "Mieszkanie Wola",
    street: "Kasprzaka 12",
    city: "Warszawa",
    role: .owner,
    inviteCode: "K7QM-4XPB",
    createdAt: baseDate,
    updatedAt: baseDate
  )

  static func makeSeededDatabase() throws -> DatabaseQueue {
    let database = try makeInMemoryDatabase()
    try database.write { db in
      try seedUserAndApartment(in: db)
      try seedMediaAndOutbox(in: db)
    }
    return database
  }

  private static func seedUserAndApartment(in db: SQLiteData.Database) throws {
    let userRecord = LocalUserRecord(profile: initialUser, isCurrentUser: true)
    try LocalUserRecord.upsert { userRecord }.execute(db)

    let apartmentRecord = ApartmentRecord(apartment: apartment)
    try ApartmentRecord.upsert { apartmentRecord }.execute(db)

    let memberRecord = MemberRecord(
      apartmentId: apartmentId,
      member: ApartmentMember(
        userId: userId,
        displayName: initialUser.displayName,
        shortTag: initialUser.shortTag,
        color: initialUser.color,
        role: .owner,
        joinedAt: baseDate
      )
    )
    try MemberRecord.upsert { memberRecord }.execute(db)
  }

  private static func seedMediaAndOutbox(in db: SQLiteData.Database) throws {
    let mediaRecord = MediaRecord(
      id: mediaId,
      apartmentId: apartmentId,
      authorId: userId,
      kind: MediaKind.photo.rawValue,
      source: MediaSource.camera.rawValue,
      sha256: sha256,
      capturedAt: baseDate,
      capturedTz: "Europe/Warsaw",
      capturedAtFromImport: false,
      serverReceivedAt: baseDate,
      width: width,
      height: height,
      bytes: bytes,
      syncState: MediaSyncState.verified.rawValue,
      localFilePath: "\(mediaId).jpg"
    )
    try MediaRecord.upsert { mediaRecord }.execute(db)

    let outboxRecord = OutboxOperationRecord(
      id: outboxId,
      apartmentId: apartmentId,
      entityType: OutboxEntityType.apartment.rawValue,
      entityId: apartmentId,
      operationType: OutboxOperationType.createApartment.rawValue,
      payloadJson: "{}",
      createdAt: baseDate,
      updatedAt: baseDate
    )
    try OutboxOperationRecord.upsert { outboxRecord }.execute(db)
  }

  static func tableCounts(in database: DatabaseQueue) throws -> ProfileTableCounts {
    try database.read { db in
      ProfileTableCounts(
        users: try LocalUserRecord.all.fetchAll(db).count,
        apartments: try ApartmentRecord.all.fetchAll(db).count,
        members: try MemberRecord.all.fetchAll(db).count,
        media: try MediaRecord.all.fetchAll(db).count,
        outbox: try OutboxOperationRecord.all.fetchAll(db).count
      )
    }
  }
}
