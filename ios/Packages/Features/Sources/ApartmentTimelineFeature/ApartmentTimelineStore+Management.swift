import Database
import DesignSystem
import Domain
import Foundation
import SQLiteData

extension ApartmentTimelineStore {
  static func fetchLocalHistory(
    apartmentId: String,
    from database: any DatabaseWriter
  ) throws -> (changes: [ApartmentChange], authorNames: [String: String]) {
    try database.read { db in
      let changeRecords =
        try ApartmentChangeRecord
        .where { $0.apartmentId.eq(apartmentId) }
        .order { $0.createdAt.desc() }
        .fetchAll(db)
      let changes = try changeRecords.map { try $0.toDomain() }

      let memberRecords =
        try MemberRecord
        .where { $0.apartmentId.eq(apartmentId) }
        .fetchAll(db)
      var authorNames: [String: String] = [:]
      for member in memberRecords {
        authorNames[member.userId] = member.displayName
      }
      if let currentUser = try LocalUserRecord.where({ $0.isCurrentUser.eq(true) }).fetchOne(db) {
        if authorNames[currentUser.id] == nil {
          authorNames[currentUser.id] = currentUser.displayName
        }
      }
      return (changes: changes, authorNames: authorNames)
    }
  }

  @discardableResult
  static func removeLocalApartment(
    apartmentId: String,
    from database: any DatabaseWriter
  ) throws -> [String] {
    // Invariant 8: Leaving or deleting removes local cached data, outbox ops, and orphaned JPEGs.
    try database.write { db in
      let mediaIds =
        try MediaRecord
        .where { $0.apartmentId.eq(apartmentId) }
        .fetchAll(db)
        .map(\.id)
      try OutboxOperationRecord
        .where { $0.apartmentId.eq(apartmentId) }
        .delete()
        .execute(db)
      try ApartmentRecord
        .where { $0.id.eq(apartmentId) }
        .delete()
        .execute(db)
      return mediaIds
    }
  }

  static func validateEditInput(
    name: String,
    street: String,
    city: String
  ) -> Result<ValidatedApartmentEdit, TimelineValidationFailure> {
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
        TimelineValidationFailure(message: L10n.errorMessage(for: .apartmentValidationFailed))
      )
    }

    return .success(
      ValidatedApartmentEdit(name: trimmedName, street: trimmedStreet, city: trimmedCity)
    )
  }
}
