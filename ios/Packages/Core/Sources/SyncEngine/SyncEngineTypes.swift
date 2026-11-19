import Foundation

public enum SyncEngineError: Error, Equatable, Sendable {
  case invalidHTTPStatus(Int)
  case missingLocalFile(mediaId: String)
  case mediaNotFound(mediaId: String)
  case entryNotFound(entryId: String)
  case invalidOperationType(String)
}

public enum SyncEvent: Equatable, Sendable {
  case uploadProgress(mediaId: String, fractionCompleted: Double)
  case quotaExceeded(apartmentId: String, mediaId: String)
  case forceUpdateRequired(minVersion: String?)
  case apartmentSynced(apartmentId: String, appliedChangesCount: Int)
  case outboxCompleted
}

public struct SyncOutboxReport: Equatable, Sendable {
  public let processedCount: Int
  public let failedCount: Int
  public let deferredCount: Int
  public let pausedForForceUpdate: Bool

  public init(
    processedCount: Int,
    failedCount: Int,
    deferredCount: Int,
    pausedForForceUpdate: Bool
  ) {
    self.processedCount = processedCount
    self.failedCount = failedCount
    self.deferredCount = deferredCount
    self.pausedForForceUpdate = pausedForForceUpdate
  }
}

public enum SyncBackoffPolicy: Sendable {
  public static func delaySeconds(forAttemptCount attemptCount: Int) -> TimeInterval {
    let clampedExponent = min(max(0, attemptCount), SyncEngineConstants.maxBackoffExponent)
    let rawDelay =
      SyncEngineConstants.baseBackoffSeconds
      * pow(SyncEngineConstants.backoffMultiplier, Double(clampedExponent))
    return min(SyncEngineConstants.maxBackoffSeconds, rawDelay)
  }

  public static func nextAttemptDate(attemptCount: Int, now: Date) -> Date {
    now.addingTimeInterval(delaySeconds(forAttemptCount: attemptCount))
  }
}
