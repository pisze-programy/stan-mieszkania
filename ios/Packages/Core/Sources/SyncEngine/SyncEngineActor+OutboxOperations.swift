import APIClient
import Database
import Domain
import Foundation
import SQLiteData

extension SyncEngineActor {
  func dispatchOperation(
    _ operation: OutboxOperationRecord
  ) async throws -> OperationExecutionOutcome {
    guard let opType = OutboxOperationType(rawValue: operation.operationType) else {
      throw SyncEngineError.invalidOperationType(operation.operationType)
    }

    switch opType {
    case .createApartment:
      try await executeCreateApartment(operation)
      return .succeeded
    case .updateApartment:
      try await executeUpdateApartment(operation)
      return .succeeded
    case .uploadMedia:
      try await executeUploadMedia(operation)
      return .succeeded
    case .createEntry:
      return try await executeCreateEntry(operation)
    case .softDeleteMedia:
      try await executeSoftDeleteMedia(operation)
      return .succeeded
    case .retractEntry:
      try await executeRetractEntry(operation)
      return .succeeded
    }
  }

  private func executeCreateApartment(_ operation: OutboxOperationRecord) async throws {
    let payload = try operation.decodePayload(CreateApartmentOutboxPayload.self)
    let synced = try await apiClient.putApartment(
      UpsertApartmentInput(
        apartmentId: payload.apartmentId,
        name: payload.name,
        street: payload.street,
        city: payload.city
      )
    )
    try await database.write { db in
      let record = ApartmentRecord(apartment: synced)
      try ApartmentRecord.upsert { record }.execute(db)
    }
  }

  private func executeUpdateApartment(_ operation: OutboxOperationRecord) async throws {
    let payload = try operation.decodePayload(UpdateApartmentOutboxPayload.self)
    let synced = try await apiClient.updateApartment(
      UpdateApartmentInput(
        apartmentId: payload.apartmentId,
        name: payload.name,
        street: payload.street,
        city: payload.city
      )
    )
    try await database.write { db in
      let record = ApartmentRecord(apartment: synced)
      try ApartmentRecord.upsert { record }.execute(db)
    }
  }

  private func executeUploadMedia(_ operation: OutboxOperationRecord) async throws {
    let payload = try operation.decodePayload(UploadMediaOutboxPayload.self)
    guard
      let mediaRecord = try await database.read({ db in
        try MediaRecord.where { $0.id.eq(payload.mediaId) }.fetchOne(db)
      })
    else {
      throw SyncEngineError.mediaNotFound(mediaId: payload.mediaId)
    }
    guard let localFilePath = mediaRecord.localFilePath else {
      throw SyncEngineError.missingLocalFile(mediaId: payload.mediaId)
    }

    let domainMedia = try mediaRecord.toDomain()
    let mediaStore = MediaMutationStore(database: database)
    try mediaStore.markMediaUploading(mediaId: payload.mediaId)

    let initResult = try await apiClient.initMediaUpload(
      InitMediaUploadInput(
        apartmentId: payload.apartmentId,
        mediaId: payload.mediaId,
        kind: domainMedia.kind,
        source: domainMedia.source,
        sha256: domainMedia.sha256,
        capturedAt: domainMedia.capturedAt,
        capturedTz: domainMedia.capturedTz,
        capturedAtFromImport: domainMedia.capturedAtFromImport,
        width: domainMedia.width,
        height: domainMedia.height,
        bytes: domainMedia.bytes,
        location: mediaRecord.captureLocation
      )
    )

    if let upload = initResult.upload {
      let broadcaster = self.broadcaster
      let mediaId = payload.mediaId
      try await objectTransfer.uploadJpeg(
        URL(fileURLWithPath: localFilePath),
        upload.url
      ) { fraction in
        broadcaster.send(.uploadProgress(mediaId: mediaId, fractionCompleted: fraction))
      }
    }

    let confirmed = try await apiClient.confirmMediaUpload(payload.apartmentId, payload.mediaId)
    let confirmedAt = confirmed.serverReceivedAt ?? clock()
    try mediaStore.confirmMediaUploaded(mediaId: payload.mediaId, serverReceivedAt: confirmedAt)
    broadcaster.send(
      .uploadProgress(mediaId: payload.mediaId, fractionCompleted: SyncEngineConstants.maxProgress)
    )
  }

  private func executeCreateEntry(
    _ operation: OutboxOperationRecord
  ) async throws -> OperationExecutionOutcome {
    let payload = try operation.decodePayload(CreateEntryOutboxPayload.self)
    guard
      let mediaRecord = try await database.read({ db in
        try MediaRecord.where { $0.id.eq(payload.mediaId) }.fetchOne(db)
      })
    else {
      throw SyncEngineError.mediaNotFound(mediaId: payload.mediaId)
    }

    // Invariant 7: Entry uploads wait until target media has serverReceivedAt confirmed.
    guard mediaRecord.isSynced else {
      return .deferred
    }

    guard
      let entryRecord = try await database.read({ db in
        try EntryRecord.where { $0.id.eq(payload.entryId) }.fetchOne(db)
      })
    else {
      throw SyncEngineError.entryNotFound(entryId: payload.entryId)
    }

    let localMarkers = try await database.read { db in
      try MarkerRecord
        .where { $0.entryId.eq(payload.entryId) }
        .order { $0.number.asc() }
        .fetchAll(db)
    }
    let draftMarkers = localMarkers.map {
      DraftMarkerInput(id: $0.id, localNumber: $0.number, x: $0.x, y: $0.y)
    }

    let confirmedEntry = try await apiClient.putMediaEntry(
      PutMediaEntryInput(
        apartmentId: payload.apartmentId,
        mediaId: payload.mediaId,
        entryId: payload.entryId,
        text: entryRecord.text,
        createdAt: entryRecord.createdAt,
        markers: draftMarkers
      )
    )

    let entryStore = EntryMutationStore(database: database)
    try entryStore.confirmEntrySynced(
      entryId: payload.entryId,
      serverReceivedAt: confirmedEntry.serverReceivedAt ?? clock(),
      serverMarkers: confirmedEntry.markers
    )
    return .succeeded
  }

  private func executeSoftDeleteMedia(_ operation: OutboxOperationRecord) async throws {
    let payload = try operation.decodePayload(SoftDeleteMediaOutboxPayload.self)
    _ = try await apiClient.softDeleteMedia(payload.apartmentId, payload.mediaId)
  }

  private func executeRetractEntry(_ operation: OutboxOperationRecord) async throws {
    let payload = try operation.decodePayload(RetractEntryOutboxPayload.self)
    _ = try await apiClient.retractMediaEntry(
      payload.apartmentId,
      payload.mediaId,
      payload.entryId
    )
  }
}
