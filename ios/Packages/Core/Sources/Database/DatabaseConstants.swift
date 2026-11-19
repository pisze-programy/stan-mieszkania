import Foundation

public enum DatabaseConstants: Sendable {
  public static let defaultFilename: String = "StanMieszkania.sqlite"
  public static let migrationV1InitialSchema: String = "v1_initial_schema"
  public static let initialSyncCursorSeq: Int = 0
  public static let initialOutboxAttemptCount: Int = 0
  public static let memberRecordIDSeparator: String = ":"
  public static let retractedEntryText: String = ""

  public enum TableName: Sendable {
    public static let localUsers: String = "local_users"
    public static let apartments: String = "apartments"
    public static let apartmentChanges: String = "apartment_changes"
    public static let members: String = "members"
    public static let media: String = "media"
    public static let entries: String = "entries"
    public static let markers: String = "markers"
    public static let outboxOperations: String = "outbox_operations"
    public static let syncCursors: String = "sync_cursors"
  }

  public enum SyncEntityType: Sendable {
    public static let apartment: String = "apartment"
    public static let membership: String = "membership"
    public static let media: String = "media"
    public static let entry: String = "entry"
  }

  public enum SyncOperation: Sendable {
    public static let deleted: String = "deleted"
    public static let softDeleted: String = "soft_deleted"
    public static let retracted: String = "retracted"
    public static let abandonedCleaned: String = "abandoned_cleaned"
  }
}
