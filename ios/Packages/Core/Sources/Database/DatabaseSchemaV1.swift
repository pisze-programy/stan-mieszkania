import SQLiteData

enum DatabaseSchemaV1: Sendable {
  static func createAllTables(in db: Database) throws {
    try createUsersAndApartments(in: db)
    try createChangesAndMembers(in: db)
    try createMediaAndEntries(in: db)
    try createMarkersOutboxAndCursors(in: db)
  }

  private static func createUsersAndApartments(in db: Database) throws {
    try #sql(
      """
      CREATE TABLE "local_users" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "displayName" TEXT NOT NULL,
        "shortTag" TEXT NOT NULL,
        "color" TEXT NOT NULL,
        "createdAt" TEXT NOT NULL,
        "isCurrentUser" INTEGER NOT NULL DEFAULT 1 CHECK ("isCurrentUser" IN (0, 1))
      ) STRICT
      """
    ).execute(db)

    try #sql(
      """
      CREATE TABLE "apartments" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "ownerId" TEXT NOT NULL,
        "name" TEXT NOT NULL,
        "street" TEXT NOT NULL,
        "city" TEXT NOT NULL,
        "role" TEXT NOT NULL CHECK ("role" IN ('owner', 'contributor')),
        "inviteCode" TEXT,
        "shouldSuggestInviteCodeReset" INTEGER NOT NULL DEFAULT 0
          CHECK ("shouldSuggestInviteCodeReset" IN (0, 1)),
        "cloudMediaCount" INTEGER NOT NULL DEFAULT 0 CHECK ("cloudMediaCount" >= 0),
        "createdAt" TEXT NOT NULL,
        "updatedAt" TEXT NOT NULL,
        "deletedAt" TEXT
      ) STRICT
      """
    ).execute(db)
  }

  private static func createChangesAndMembers(in db: Database) throws {
    try #sql(
      """
      CREATE TABLE "apartment_changes" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "apartmentId" TEXT NOT NULL REFERENCES "apartments"("id") ON DELETE CASCADE,
        "authorId" TEXT NOT NULL,
        "field" TEXT NOT NULL CHECK ("field" IN ('name', 'street', 'city')),
        "oldValue" TEXT NOT NULL,
        "newValue" TEXT NOT NULL,
        "createdAt" TEXT NOT NULL
      ) STRICT
      """
    ).execute(db)

    try #sql(
      """
      CREATE TABLE "members" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "apartmentId" TEXT NOT NULL REFERENCES "apartments"("id") ON DELETE CASCADE,
        "userId" TEXT NOT NULL,
        "displayName" TEXT NOT NULL,
        "shortTag" TEXT NOT NULL,
        "color" TEXT NOT NULL,
        "role" TEXT NOT NULL CHECK ("role" IN ('owner', 'contributor')),
        "joinedAt" TEXT NOT NULL,
        "leftAt" TEXT,
        UNIQUE ("apartmentId", "userId")
      ) STRICT
      """
    ).execute(db)
  }

  private static func createMediaAndEntries(in db: Database) throws {
    try #sql(
      """
      CREATE TABLE "media" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "apartmentId" TEXT NOT NULL REFERENCES "apartments"("id") ON DELETE CASCADE,
        "authorId" TEXT NOT NULL,
        "kind" TEXT NOT NULL CHECK ("kind" IN ('photo', 'video')),
        "source" TEXT NOT NULL CHECK ("source" IN ('camera', 'import')),
        "sha256" TEXT NOT NULL,
        "capturedAt" TEXT NOT NULL,
        "capturedTz" TEXT NOT NULL,
        "capturedAtFromImport" INTEGER NOT NULL DEFAULT 0 CHECK ("capturedAtFromImport" IN (0, 1)),
        "serverReceivedAt" TEXT,
        "width" INTEGER NOT NULL CHECK ("width" > 0),
        "height" INTEGER NOT NULL CHECK ("height" > 0),
        "bytes" INTEGER NOT NULL CHECK ("bytes" > 0),
        "syncState" TEXT NOT NULL
          CHECK ("syncState" IN ('localOnly', 'queued', 'uploading', 'verified', 'softDeleted')),
        "localFilePath" TEXT,
        "captureLat" REAL,
        "captureLng" REAL,
        "captureAccuracyM" REAL,
        "captureLocationSource" TEXT,
        "deletedAt" TEXT,
        "deletedBy" TEXT
      ) STRICT
      """
    ).execute(db)

    try #sql(
      """
      CREATE TABLE "entries" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "mediaId" TEXT NOT NULL REFERENCES "media"("id") ON DELETE CASCADE,
        "authorId" TEXT NOT NULL,
        "text" TEXT NOT NULL,
        "createdAt" TEXT NOT NULL,
        "serverReceivedAt" TEXT,
        "retractedAt" TEXT
      ) STRICT
      """
    ).execute(db)
  }

  private static func createMarkersOutboxAndCursors(in db: Database) throws {
    try #sql(
      """
      CREATE TABLE "markers" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "entryId" TEXT NOT NULL REFERENCES "entries"("id") ON DELETE CASCADE,
        "mediaId" TEXT NOT NULL REFERENCES "media"("id") ON DELETE CASCADE,
        "number" INTEGER NOT NULL CHECK ("number" > 0),
        "isServerAssigned" INTEGER NOT NULL DEFAULT 0 CHECK ("isServerAssigned" IN (0, 1)),
        "x" REAL NOT NULL CHECK ("x" >= 0.0 AND "x" <= 1.0),
        "y" REAL NOT NULL CHECK ("y" >= 0.0 AND "y" <= 1.0)
      ) STRICT
      """
    ).execute(db)

    try #sql(
      """
      CREATE TABLE "outbox_operations" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "apartmentId" TEXT NOT NULL,
        "entityType" TEXT NOT NULL CHECK ("entityType" IN ('apartment', 'media', 'entry')),
        "entityId" TEXT NOT NULL,
        "operationType" TEXT NOT NULL,
        "payloadJson" TEXT NOT NULL,
        "status" TEXT NOT NULL CHECK ("status" IN ('pending', 'inFlight', 'failed')),
        "attemptCount" INTEGER NOT NULL DEFAULT 0 CHECK ("attemptCount" >= 0),
        "lastErrorCode" TEXT,
        "nextAttemptAt" TEXT,
        "createdAt" TEXT NOT NULL,
        "updatedAt" TEXT NOT NULL
      ) STRICT
      """
    ).execute(db)

    try #sql(
      """
      CREATE TABLE "sync_cursors" (
        "apartmentId" TEXT NOT NULL PRIMARY KEY REFERENCES "apartments"("id") ON DELETE CASCADE,
        "lastSeq" INTEGER NOT NULL DEFAULT 0 CHECK ("lastSeq" >= 0),
        "updatedAt" TEXT NOT NULL
      ) STRICT
      """
    ).execute(db)
  }
}
