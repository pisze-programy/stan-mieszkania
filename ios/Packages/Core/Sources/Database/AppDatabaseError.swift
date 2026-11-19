import Foundation

public enum AppDatabaseError: Error, Equatable, Sendable {
  case apartmentNotFound(String)
  case mediaNotFound(String)
  case entryNotFound(String)
  case outboxOperationNotFound(String)
  case cannotHardDeleteSyncedMedia(String)
  case cannotSoftDeleteUnsyncedMedia(String)
  case cannotEditSyncedEntry(String)
  case cannotHardDeleteSyncedEntry(String)
  case cannotRetractUnsyncedEntry(String)
  case mediaAuthorMismatch(mediaId: String, actorId: String)
  case entryAuthorMismatch(entryId: String, actorId: String)
  case mediaAlreadySoftDeleted(String)
  case entryAlreadyRetracted(String)
  case invalidMediaStateTransition(mediaId: String, currentState: String)
  case invalidPayloadEncoding(String)
  case invalidStoredEnumValue(column: String, value: String)
  case invalidSyncChange(String)
}
