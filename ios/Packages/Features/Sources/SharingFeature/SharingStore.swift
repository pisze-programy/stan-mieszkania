import Database
import Domain
import Foundation
import SQLiteData

enum SharingStore {
  static func fetchCachedState(
    apartmentId: String,
    from database: any DatabaseWriter
  ) throws -> (apartment: Apartment?, members: [ApartmentMember]) {
    try database.read { db in
      let apartment =
        try ApartmentRecord
        .where { $0.id.eq(apartmentId) }
        .fetchOne(db)?
        .toDomain()

      let memberRecords =
        try MemberRecord
        .where { $0.apartmentId.eq(apartmentId) }
        .order { $0.joinedAt.asc() }
        .fetchAll(db)

      let members = try memberRecords.map { try $0.toDomain() }
      return (apartment: apartment, members: members)
    }
  }

  static func saveFetchedState(
    apartment: Apartment,
    members: [ApartmentMember],
    in database: any DatabaseWriter
  ) throws {
    try database.write { db in
      let apartmentRecord = ApartmentRecord(apartment: apartment)
      try ApartmentRecord.upsert { apartmentRecord }.execute(db)

      for member in members {
        let memberRecord = MemberRecord(apartmentId: apartment.id, member: member)
        try MemberRecord.upsert { memberRecord }.execute(db)
      }
    }
  }

  static func saveApartment(
    _ apartment: Apartment,
    in database: any DatabaseWriter
  ) throws {
    try database.write { db in
      let apartmentRecord = ApartmentRecord(apartment: apartment)
      try ApartmentRecord.upsert { apartmentRecord }.execute(db)
    }
  }

  static func markMemberRevoked(
    apartmentId: String,
    userId: String,
    leftAt: Date,
    in database: any DatabaseWriter
  ) throws {
    let recordId = MemberRecord.makeID(apartmentId: apartmentId, userId: userId)
    let revokedAt: Date? = leftAt
    try database.write { db in
      try MemberRecord
        .where { $0.id.eq(recordId) }
        .update { $0.leftAt = revokedAt }
        .execute(db)
    }
  }

  static func hasPendingCreateOperation(
    apartmentId: String,
    in database: any DatabaseWriter
  ) throws -> Bool {
    let ops = try OutboxRepository(database: database).fetchAllOperations()
    let createOpType = OutboxOperationType.createApartment.rawValue
    return ops.contains { $0.apartmentId == apartmentId && $0.operationType == createOpType }
  }
}
