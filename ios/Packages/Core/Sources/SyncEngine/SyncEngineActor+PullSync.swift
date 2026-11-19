import APIClient
import Database
import Domain
import Foundation
import SQLiteData

extension SyncEngineActor {
  // Decision S2-11 & A16: Reconcile active apartments and pull change feeds for any ahead headSeq.
  @discardableResult
  public func syncAllOnEntry() async throws -> Int {
    let summaries = try await apiClient.listMyApartmentsSync()
    let applier = SyncDeltaApplier(database: database)
    let now = clock()

    try await database.write { db in
      for summary in summaries {
        let record = ApartmentRecord(apartment: summary.apartment)
        try ApartmentRecord.upsert { record }.execute(db)
        let existingCursor =
          try SyncCursorRecord
          .where { $0.apartmentId.eq(summary.apartment.id) }
          .fetchOne(db)
        if existingCursor == nil {
          let initialCursor = SyncCursorRecord(
            apartmentId: summary.apartment.id,
            lastSeq: DatabaseConstants.initialSyncCursorSeq,
            updatedAt: now
          )
          try SyncCursorRecord.insert { initialCursor }.execute(db)
        }
      }
    }

    var totalApplied = 0
    for summary in summaries {
      let localSeq = try applier.fetchLastSeq(apartmentId: summary.apartment.id)
      if summary.headSeq > localSeq {
        totalApplied += try await syncApartment(apartmentId: summary.apartment.id)
      }
    }
    return totalApplied
  }

  // Architecture A16 & §5: Exhaust all cursor pages until hasMore == false with zero artificial cap.
  @discardableResult
  public func syncApartment(apartmentId: String) async throws -> Int {
    let applier = SyncDeltaApplier(database: database)
    var cursor = try applier.fetchLastSeq(apartmentId: apartmentId)
    var totalApplied = 0

    while true {
      let page = try await apiClient.listApartmentChanges(
        apartmentId,
        cursor,
        SyncEngineConstants.changeFeedPageSize
      )

      if !page.changes.isEmpty {
        let dbChanges = page.changes.map(SyncDeltaBridge.toDatabaseChange)
        try applier.applyHydratedChanges(dbChanges, now: clock())
        totalApplied += dbChanges.count
      }

      guard page.hasMore else {
        break
      }
      guard let nextSeq = page.nextSeq, nextSeq > cursor else {
        break
      }
      cursor = nextSeq
    }

    broadcaster.send(.apartmentSynced(apartmentId: apartmentId, appliedChangesCount: totalApplied))
    return totalApplied
  }
}
