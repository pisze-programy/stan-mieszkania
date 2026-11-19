import Foundation
import SQLiteData

@Table("sync_cursors")
public struct SyncCursorRecord: Equatable, Hashable, Sendable {
  @Column(primaryKey: true)
  public let apartmentId: String
  public var lastSeq: Int
  public var updatedAt: Date

  public init(
    apartmentId: String,
    lastSeq: Int = DatabaseConstants.initialSyncCursorSeq,
    updatedAt: Date
  ) {
    self.apartmentId = apartmentId
    self.lastSeq = lastSeq
    self.updatedAt = updatedAt
  }
}
