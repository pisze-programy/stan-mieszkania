import Database
import Domain
import Foundation
import SQLiteData

enum ProfileStore {
  static func fetchCurrentUser(from database: any DatabaseWriter) throws -> UserProfile? {
    try ApartmentMutationStore(database: database).fetchCurrentUser()
  }

  static func saveUpdatedUser(
    _ profile: UserProfile,
    in database: any DatabaseWriter
  ) throws {
    try database.write { db in
      try LocalUserRecord
        .where { $0.isCurrentUser.eq(true) }
        .update { $0.isCurrentUser = false }
        .execute(db)

      let userRecord = LocalUserRecord(profile: profile, isCurrentUser: true)
      try LocalUserRecord.upsert { userRecord }.execute(db)

      try MemberRecord
        .where { $0.userId.eq(profile.id) }
        .update { $0.displayName = profile.displayName }
        .execute(db)
    }
  }

  // Decision Q5 & Invariant 8: Clear all local SQLite tables and return media IDs for JPEG cleanup.
  @discardableResult
  static func wipeAllLocalData(in database: any DatabaseWriter) throws -> [String] {
    try database.write { db in
      let mediaIds = try MediaRecord.all.fetchAll(db).map(\.id)
      try OutboxOperationRecord.delete().execute(db)
      try SyncCursorRecord.delete().execute(db)
      try MarkerRecord.delete().execute(db)
      try EntryRecord.delete().execute(db)
      try MediaRecord.delete().execute(db)
      try MemberRecord.delete().execute(db)
      try ApartmentChangeRecord.delete().execute(db)
      try ApartmentRecord.delete().execute(db)
      try LocalUserRecord.delete().execute(db)
      return mediaIds
    }
  }
}
