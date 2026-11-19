import Database
import Domain
import Foundation

enum SyncDeltaTestFixtures {
  static func apartmentCreated() -> HydratedSyncChange {
    HydratedSyncChange(
      seq: DatabaseTestFixtures.seqOne,
      apartmentId: DatabaseTestFixtures.apartmentId,
      entityType: DatabaseConstants.SyncEntityType.apartment,
      entityId: DatabaseTestFixtures.apartmentId,
      op: "created",
      createdAt: DatabaseTestFixtures.baseDate,
      payload: .apartment(DatabaseTestFixtures.makeApartment())
    )
  }

  static func memberJoined() -> HydratedSyncChange {
    HydratedSyncChange(
      seq: DatabaseTestFixtures.seqTwo,
      apartmentId: DatabaseTestFixtures.apartmentId,
      entityType: DatabaseConstants.SyncEntityType.membership,
      entityId: DatabaseTestFixtures.contributorId,
      op: "joined",
      createdAt: DatabaseTestFixtures.plusOneMinute,
      payload: .member(DatabaseTestFixtures.makeContributorMember())
    )
  }

  static func mediaConfirmed() -> HydratedSyncChange {
    HydratedSyncChange(
      seq: DatabaseTestFixtures.seqThree,
      apartmentId: DatabaseTestFixtures.apartmentId,
      entityType: DatabaseConstants.SyncEntityType.media,
      entityId: DatabaseTestFixtures.mediaId,
      op: "confirmed",
      createdAt: DatabaseTestFixtures.plusTwoMinutes,
      payload: .media(
        HydratedSyncMedia(
          id: DatabaseTestFixtures.mediaId,
          apartmentId: DatabaseTestFixtures.apartmentId,
          authorId: DatabaseTestFixtures.ownerId,
          kind: .photo,
          source: .camera,
          uploadStatus: .uploaded,
          sha256: DatabaseTestFixtures.sha256,
          capturedAt: DatabaseTestFixtures.baseDate,
          capturedTz: "Europe/Warsaw",
          capturedAtFromImport: false,
          serverReceivedAt: DatabaseTestFixtures.plusTwoMinutes,
          width: DatabaseTestFixtures.width,
          height: DatabaseTestFixtures.height,
          bytes: DatabaseTestFixtures.bytes,
          deletedAt: nil,
          deletedBy: nil,
          author: DatabaseTestFixtures.makeOwnerSummary()
        )
      )
    )
  }

  static func entryCreated() -> HydratedSyncChange {
    let marker = DatabaseTestFixtures.makeMarker(
      id: DatabaseTestFixtures.markerOneId,
      number: DatabaseTestFixtures.markerOneNumber,
      isServerAssigned: true
    )
    return HydratedSyncChange(
      seq: DatabaseTestFixtures.seqFour,
      apartmentId: DatabaseTestFixtures.apartmentId,
      entityType: DatabaseConstants.SyncEntityType.entry,
      entityId: DatabaseTestFixtures.entryId,
      op: "created",
      createdAt: DatabaseTestFixtures.plusTwoMinutes,
      payload: .entry(
        HydratedSyncEntry(
          id: DatabaseTestFixtures.entryId,
          mediaId: DatabaseTestFixtures.mediaId,
          authorId: DatabaseTestFixtures.ownerId,
          text: "Zarysowanie [1]",
          markers: [marker],
          createdAt: DatabaseTestFixtures.plusTwoMinutes,
          serverReceivedAt: DatabaseTestFixtures.plusTwoMinutes,
          retractedAt: nil,
          author: DatabaseTestFixtures.makeOwnerSummary()
        )
      )
    )
  }

  static func entryRetractedTombstone() -> HydratedSyncChange {
    HydratedSyncChange(
      seq: DatabaseTestFixtures.seqFive,
      apartmentId: DatabaseTestFixtures.apartmentId,
      entityType: DatabaseConstants.SyncEntityType.entry,
      entityId: DatabaseTestFixtures.entryId,
      op: DatabaseConstants.SyncOperation.retracted,
      createdAt: DatabaseTestFixtures.plusThreeMinutes,
      payload: nil
    )
  }

  static func mediaSoftDeletedTombstone() -> HydratedSyncChange {
    HydratedSyncChange(
      seq: DatabaseTestFixtures.seqSix,
      apartmentId: DatabaseTestFixtures.apartmentId,
      entityType: DatabaseConstants.SyncEntityType.media,
      entityId: DatabaseTestFixtures.mediaId,
      op: DatabaseConstants.SyncOperation.softDeleted,
      createdAt: DatabaseTestFixtures.plusFiveMinutes,
      payload: nil
    )
  }
}
