import Domain
import Foundation
import SQLiteData

public struct ApartmentMetadataUpdate: Sendable, Equatable {
  public let apartmentId: String
  public let name: String
  public let street: String
  public let city: String
  public let authorId: String

  public init(
    apartmentId: String,
    name: String,
    street: String,
    city: String,
    authorId: String
  ) {
    self.apartmentId = apartmentId
    self.name = name
    self.street = street
    self.city = city
    self.authorId = authorId
  }
}

public struct ApartmentMutationStore: Sendable {
  private struct FieldDiff {
    let field: ApartmentEditableField
    let oldValue: String
    let newValue: String
  }

  let database: any DatabaseWriter

  public init(database: any DatabaseWriter) {
    self.database = database
  }

  public func saveLocalUser(_ profile: UserProfile, isCurrentUser: Bool = true) throws {
    try database.write { db in
      if isCurrentUser {
        try LocalUserRecord
          .where { $0.isCurrentUser.eq(true) }
          .update { $0.isCurrentUser = false }
          .execute(db)
      }
      let record = LocalUserRecord(profile: profile, isCurrentUser: isCurrentUser)
      try LocalUserRecord.upsert { record }.execute(db)
    }
  }

  public func fetchCurrentUser() throws -> UserProfile? {
    try database.read { db in
      try LocalUserRecord
        .where { $0.isCurrentUser.eq(true) }
        .fetchOne(db)?
        .toDomain()
    }
  }

  // Decision S2-8: Apartment metadata always synchronizes to the cloud via the outbox.
  public func createApartment(
    _ apartment: Apartment,
    creator: ApartmentMember,
    outboxId: String = UUIDv7.generateNow(),
    now: Date
  ) throws {
    try database.write { db in
      let apartmentRecord = ApartmentRecord(apartment: apartment)
      let memberRecord = MemberRecord(apartmentId: apartment.id, member: creator)
      let cursorRecord = SyncCursorRecord(apartmentId: apartment.id, updatedAt: now)

      try ApartmentRecord.insert { apartmentRecord }.execute(db)
      try MemberRecord.upsert { memberRecord }.execute(db)
      try SyncCursorRecord.upsert { cursorRecord }.execute(db)

      let payload = CreateApartmentOutboxPayload(
        apartmentId: apartment.id,
        name: apartment.name,
        street: apartment.street,
        city: apartment.city
      )
      try OutboxRepository.enqueue(
        in: db,
        request: OutboxEnqueueRequest(
          id: outboxId,
          apartmentId: apartment.id,
          entityType: .apartment,
          entityId: apartment.id,
          operationType: .createApartment,
          payload: payload,
          now: now
        )
      )
    }
  }

  // Decision S2-8 & S2-9: Metadata edits record change history and always enqueue outbox sync.
  @discardableResult
  public func updateApartmentMetadata(
    _ update: ApartmentMetadataUpdate,
    outboxId: String = UUIDv7.generateNow(),
    changeIDGenerator: @Sendable () -> String = UUIDv7.generateNow,
    now: Date
  ) throws -> ApartmentRecord {
    try database.write { db in
      guard
        var existing = try ApartmentRecord.where({ $0.id.eq(update.apartmentId) }).fetchOne(db)
      else {
        throw AppDatabaseError.apartmentNotFound(update.apartmentId)
      }

      let fieldDiffs = [
        FieldDiff(field: .name, oldValue: existing.name, newValue: update.name),
        FieldDiff(field: .street, oldValue: existing.street, newValue: update.street),
        FieldDiff(field: .city, oldValue: existing.city, newValue: update.city),
      ]

      for diff in fieldDiffs where diff.oldValue != diff.newValue {
        let changeRecord = ApartmentChangeRecord(
          id: changeIDGenerator(),
          apartmentId: update.apartmentId,
          authorId: update.authorId,
          field: diff.field.rawValue,
          oldValue: diff.oldValue,
          newValue: diff.newValue,
          createdAt: now
        )
        try ApartmentChangeRecord.insert { changeRecord }.execute(db)
      }

      existing.name = update.name
      existing.street = update.street
      existing.city = update.city
      existing.updatedAt = now
      try ApartmentRecord.upsert { existing }.execute(db)

      let payload = UpdateApartmentOutboxPayload(
        apartmentId: update.apartmentId,
        name: update.name,
        street: update.street,
        city: update.city
      )
      try OutboxRepository.enqueue(
        in: db,
        request: OutboxEnqueueRequest(
          id: outboxId,
          apartmentId: update.apartmentId,
          entityType: .apartment,
          entityId: update.apartmentId,
          operationType: .updateApartment,
          payload: payload,
          now: now
        )
      )
      return existing
    }
  }

  public func upsertApartmentChanges(_ changes: [ApartmentChange]) throws {
    guard !changes.isEmpty else {
      return
    }
    try database.write { db in
      for change in changes {
        let record = ApartmentChangeRecord(change: change)
        try ApartmentChangeRecord.upsert { record }.execute(db)
      }
    }
  }
}
