import APIClient
import Database
import Domain
import Foundation
import SQLiteData

enum OperationExecutionOutcome: Sendable {
  case succeeded
  case deferred
  case dropped
}

extension SyncEngineActor {
  public func processOutbox() async -> SyncOutboxReport {
    let outbox = OutboxRepository(database: database)
    var processedCount = 0
    var failedCount = 0
    var deferredCount = 0

    let runnable: [OutboxOperationRecord]
    do {
      runnable = try outbox.fetchRunnableOperations(
        asOf: clock(),
        limit: SyncEngineConstants.outboxBatchLimit
      )
    } catch {
      return SyncOutboxReport(
        processedCount: 0,
        failedCount: 1,
        deferredCount: 0,
        pausedForForceUpdate: false
      )
    }

    let ordered = sortCausally(runnable)
    for operation in ordered {
      let stepResult = await executeSingleOperation(operation, outbox: outbox)
      switch stepResult {
      case .processed:
        processedCount += 1
      case .deferred:
        deferredCount += 1
      case .skipped:
        break
      case .failed:
        failedCount += 1
      case .pausedForForceUpdate:
        return SyncOutboxReport(
          processedCount: processedCount,
          failedCount: failedCount,
          deferredCount: deferredCount,
          pausedForForceUpdate: true
        )
      }
    }

    broadcaster.send(.outboxCompleted)
    return SyncOutboxReport(
      processedCount: processedCount,
      failedCount: failedCount,
      deferredCount: deferredCount,
      pausedForForceUpdate: false
    )
  }

  private enum OutboxStepOutcome {
    case processed
    case deferred
    case skipped
    case failed
    case pausedForForceUpdate
  }

  private func executeSingleOperation(
    _ operation: OutboxOperationRecord,
    outbox: OutboxRepository
  ) async -> OutboxStepOutcome {
    let now = clock()
    do {
      try outbox.markInFlight(id: operation.id, now: now)
    } catch AppDatabaseError.outboxOperationNotFound {
      return .skipped
    } catch {
      return .failed
    }

    do {
      let outcome = try await dispatchOperation(operation)
      switch outcome {
      case .succeeded:
        try outbox.markSucceeded(id: operation.id)
        return .processed
      case .deferred:
        try outbox.resetToPending(id: operation.id, now: clock())
        return .deferred
      case .dropped:
        try outbox.markSucceeded(id: operation.id)
        return .skipped
      }
    } catch let problem as APIProblemError {
      return handleProblemError(problem, for: operation, outbox: outbox)
    } catch {
      let failureNow = clock()
      let nextAttempt = SyncBackoffPolicy.nextAttemptDate(
        attemptCount: operation.attemptCount,
        now: failureNow
      )
      try? outbox.markFailed(
        id: operation.id,
        errorCode: SyncEngineConstants.transientErrorCode,
        nextAttemptAt: nextAttempt,
        now: failureNow
      )
      return .failed
    }
  }

  private func handleProblemError(
    _ problem: APIProblemError,
    for operation: OutboxOperationRecord,
    outbox: OutboxRepository
  ) -> OutboxStepOutcome {
    // Architecture A19: Pause outbox cleanly on 426 APP_UPDATE_REQUIRED without dropping queued ops.
    if problem.isUpdateRequired {
      try? outbox.resetToPending(id: operation.id, now: clock())
      broadcaster.send(.forceUpdateRequired(minVersion: nil))
      return .pausedForForceUpdate
    }

    // Decision S2-4/5: Revert queued/uploading media to localOnly on QUOTA_EXCEEDED without data loss.
    let isQuotaUpload =
      problem.isQuotaExceeded && operation.operationType == OutboxOperationType.uploadMedia.rawValue
    if isQuotaUpload {
      let mediaStore = MediaMutationStore(database: database)
      try? mediaStore.handleQuotaExceeded(mediaId: operation.entityId)
      broadcaster.send(
        .quotaExceeded(apartmentId: operation.apartmentId, mediaId: operation.entityId)
      )
      return .failed
    }

    if isIdempotentAlreadyApplied(problem, operationType: operation.operationType) {
      try? outbox.markSucceeded(id: operation.id)
      return .processed
    }

    let failureNow = clock()
    let nextAttempt = SyncBackoffPolicy.nextAttemptDate(
      attemptCount: operation.attemptCount,
      now: failureNow
    )
    try? outbox.markFailed(
      id: operation.id,
      errorCode: problem.code.rawValue,
      nextAttemptAt: nextAttempt,
      now: failureNow
    )
    return .failed
  }

  private func isIdempotentAlreadyApplied(
    _ problem: APIProblemError,
    operationType: String
  ) -> Bool {
    switch (operationType, problem.code) {
    case (OutboxOperationType.softDeleteMedia.rawValue, .known(.mediaAlreadyDeleted)):
      return true
    case (OutboxOperationType.retractEntry.rawValue, .known(.entryAlreadyRetracted)):
      return true
    default:
      return false
    }
  }

  private func sortCausally(_ operations: [OutboxOperationRecord]) -> [OutboxOperationRecord] {
    operations.sorted { lhs, rhs in
      let leftRank = causalRank(for: lhs.operationType)
      let rightRank = causalRank(for: rhs.operationType)
      if leftRank != rightRank { return leftRank < rightRank }
      if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
      return lhs.id < rhs.id
    }
  }

  private func causalRank(for operationType: String) -> Int {
    guard let parsed = OutboxOperationType(rawValue: operationType) else {
      return SyncEngineConstants.rankUnknown
    }
    switch parsed {
    case .createApartment, .updateApartment:
      return SyncEngineConstants.rankApartment
    case .uploadMedia:
      return SyncEngineConstants.rankMediaUpload
    case .createEntry:
      return SyncEngineConstants.rankEntryCreate
    case .softDeleteMedia, .retractEntry:
      return SyncEngineConstants.rankTombstone
    }
  }
}
