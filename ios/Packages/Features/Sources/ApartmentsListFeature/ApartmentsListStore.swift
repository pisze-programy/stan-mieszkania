import Database
import DesignSystem
import Domain
import Foundation
import SQLiteData

public struct ApartmentListItem: Identifiable, Equatable, Sendable {
  public let apartment: Apartment
  public let photoCount: Int

  public var id: String { apartment.id }

  public init(apartment: Apartment, photoCount: Int) {
    self.apartment = apartment
    self.photoCount = photoCount
  }
}

public struct CreateApartmentInput: Equatable, Sendable {
  public let name: String
  public let street: String
  public let city: String
}

enum ApartmentsListStore {
  static func fetchSnapshot(
    from database: any DatabaseWriter
  ) throws -> (user: UserProfile?, items: [ApartmentListItem]) {
    try database.read { db in
      let user =
        try LocalUserRecord
        .where { $0.isCurrentUser.eq(true) }
        .fetchOne(db)?
        .toDomain()

      let apartmentRecords =
        try ApartmentRecord
        .where { $0.deletedAt.is(nil) }
        .order { $0.createdAt.desc() }
        .fetchAll(db)

      let activeMedia =
        try MediaRecord
        .where { $0.deletedAt.is(nil) }
        .fetchAll(db)

      var countsByApartment: [String: Int] = [:]
      for media in activeMedia {
        countsByApartment[media.apartmentId, default: 0] += 1
      }

      let items = try apartmentRecords.map { record in
        let apartment = try record.toDomain()
        let count = countsByApartment[apartment.id] ?? 0
        return ApartmentListItem(apartment: apartment, photoCount: count)
      }

      return (user: user, items: items)
    }
  }

  static func saveJoinedApartment(
    _ apartment: Apartment,
    in database: any DatabaseWriter,
    now: Date
  ) throws {
    try database.write { db in
      let record = ApartmentRecord(apartment: apartment)
      try ApartmentRecord.upsert { record }.execute(db)

      let existingCursor =
        try SyncCursorRecord
        .where { $0.apartmentId.eq(apartment.id) }
        .fetchOne(db)
      if existingCursor == nil {
        let cursor = SyncCursorRecord(
          apartmentId: apartment.id,
          lastSeq: DatabaseConstants.initialSyncCursorSeq,
          updatedAt: now
        )
        try SyncCursorRecord.insert { cursor }.execute(db)
      }
    }
  }

  static func validateCreateInput(
    name: String,
    street: String,
    city: String
  ) -> Result<CreateApartmentInput, ApartmentValidationFailure> {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedStreet = street.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)

    guard
      trimmedName.count >= ContractConstants.apartmentNameMinLength,
      trimmedName.count <= ContractConstants.apartmentNameMaxLength,
      trimmedStreet.count >= ContractConstants.apartmentStreetMinLength,
      trimmedStreet.count <= ContractConstants.apartmentStreetMaxLength,
      trimmedCity.count >= ContractConstants.apartmentCityMinLength,
      trimmedCity.count <= ContractConstants.apartmentCityMaxLength
    else {
      return .failure(
        ApartmentValidationFailure(message: L10n.errorMessage(for: .apartmentValidationFailed))
      )
    }

    return .success(
      CreateApartmentInput(name: trimmedName, street: trimmedStreet, city: trimmedCity)
    )
  }
}

struct ApartmentValidationFailure: Error, Equatable {
  let message: String
}
