import Domain
import Foundation
import SQLiteData

extension ApartmentMutationStore {
  // Invariant 8: Prune locally cached apartments where membership ended and return orphaned media IDs.
  @discardableResult
  public func pruneRevokedApartments(
    keepingActiveApartmentIds activeIds: Set<String>
  ) throws -> [String] {
    try database.write { db in
      let localApartments =
        try ApartmentRecord
        .where { $0.deletedAt.is(nil) }
        .fetchAll(db)

      let createOpType = OutboxOperationType.createApartment.rawValue
      let pendingCreateIds = Set(
        try OutboxOperationRecord
          .where { $0.operationType.eq(createOpType) }
          .fetchAll(db)
          .map(\.apartmentId)
      )

      var deletedMediaIds: [String] = []
      for apartment in localApartments {
        if activeIds.contains(apartment.id) || pendingCreateIds.contains(apartment.id) {
          continue
        }
        let mediaIds =
          try MediaRecord
          .where { $0.apartmentId.eq(apartment.id) }
          .fetchAll(db)
          .map(\.id)
        deletedMediaIds.append(contentsOf: mediaIds)
        try OutboxRepository.deleteOperationsForApartment(in: db, apartmentId: apartment.id)
        try ApartmentRecord
          .where { $0.id.eq(apartment.id) }
          .delete()
          .execute(db)
      }
      return deletedMediaIds
    }
  }
}
