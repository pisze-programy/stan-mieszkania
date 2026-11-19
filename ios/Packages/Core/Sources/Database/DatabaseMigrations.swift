import SQLiteData

public enum DatabaseMigrations: Sendable {
  public static func makeMigrator() -> DatabaseMigrator {
    var migrator = DatabaseMigrator()
    migrator.registerMigration(DatabaseConstants.migrationV1InitialSchema) { db in
      try DatabaseSchemaV1.createAllTables(in: db)
      try createCoreIndexesV1(in: db)
      try createEvidenceAndOutboxIndexesV1(in: db)
    }
    return migrator
  }

  private static func createCoreIndexesV1(in db: Database) throws {
    try #sql(
      """
      CREATE INDEX "idx_apartment_changes_apartment_created"
      ON "apartment_changes" ("apartmentId", "createdAt" ASC)
      """
    ).execute(db)

    try #sql(
      """
      CREATE INDEX "idx_members_apartment_left"
      ON "members" ("apartmentId", "leftAt")
      """
    ).execute(db)

    try #sql(
      """
      CREATE INDEX "idx_media_apartment_captured"
      ON "media" ("apartmentId", "capturedAt" DESC)
      """
    ).execute(db)

    try #sql(
      """
      CREATE INDEX "idx_media_sync_state"
      ON "media" ("apartmentId", "syncState")
      """
    ).execute(db)

    try #sql(
      """
      CREATE INDEX "idx_entries_media_created"
      ON "entries" ("mediaId", "createdAt" ASC)
      """
    ).execute(db)
  }

  private static func createEvidenceAndOutboxIndexesV1(in db: Database) throws {
    try #sql(
      """
      CREATE INDEX "idx_markers_entry_id"
      ON "markers" ("entryId")
      """
    ).execute(db)

    try #sql(
      """
      CREATE INDEX "idx_markers_media_number"
      ON "markers" ("mediaId", "number")
      """
    ).execute(db)

    // Invariant 5: Server-assigned marker numbers are unique per photo while local drafts remain temporary.
    try #sql(
      """
      CREATE UNIQUE INDEX "idx_markers_media_server_number_unique"
      ON "markers" ("mediaId", "number")
      WHERE "isServerAssigned" = 1
      """
    ).execute(db)

    try #sql(
      """
      CREATE INDEX "idx_outbox_status_created"
      ON "outbox_operations" ("status", "createdAt" ASC, "id" ASC)
      """
    ).execute(db)

    try #sql(
      """
      CREATE INDEX "idx_outbox_entity"
      ON "outbox_operations" ("entityType", "entityId")
      """
    ).execute(db)
  }
}
