import Domain
import Foundation
import SQLiteData

public enum OutboxEntityType: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
  case apartment
  case media
  case entry
}

public enum OutboxOperationType: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
  case createApartment
  case updateApartment
  case uploadMedia
  case softDeleteMedia
  case createEntry
  case retractEntry
}

public enum OutboxOperationStatus: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
  case pending
  case inFlight
  case failed
}

@Table("outbox_operations")
public struct OutboxOperationRecord: Identifiable, Equatable, Hashable, Sendable {
  public let id: String
  public let apartmentId: String
  public let entityType: String
  public let entityId: String
  public let operationType: String
  public var payloadJson: String
  public var status: String
  public var attemptCount: Int
  public var lastErrorCode: String?
  public var nextAttemptAt: Date?
  public let createdAt: Date
  public var updatedAt: Date

  public init(
    id: String,
    apartmentId: String,
    entityType: String,
    entityId: String,
    operationType: String,
    payloadJson: String,
    status: String = OutboxOperationStatus.pending.rawValue,
    attemptCount: Int = DatabaseConstants.initialOutboxAttemptCount,
    lastErrorCode: String? = nil,
    nextAttemptAt: Date? = nil,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.apartmentId = apartmentId
    self.entityType = entityType
    self.entityId = entityId
    self.operationType = operationType
    self.payloadJson = payloadJson
    self.status = status
    self.attemptCount = attemptCount
    self.lastErrorCode = lastErrorCode
    self.nextAttemptAt = nextAttemptAt
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  public func decodePayload<T: Decodable>(_ type: T.Type) throws -> T {
    guard let data = payloadJson.data(using: .utf8) else {
      throw AppDatabaseError.invalidPayloadEncoding(id)
    }
    return try OutboxPayloadCodec.decode(type, from: data)
  }
}

public struct CreateApartmentOutboxPayload: Codable, Equatable, Sendable {
  public let apartmentId: String
  public let name: String
  public let street: String
  public let city: String

  public init(apartmentId: String, name: String, street: String, city: String) {
    self.apartmentId = apartmentId
    self.name = name
    self.street = street
    self.city = city
  }
}

public struct UpdateApartmentOutboxPayload: Codable, Equatable, Sendable {
  public let apartmentId: String
  public let name: String
  public let street: String
  public let city: String

  public init(apartmentId: String, name: String, street: String, city: String) {
    self.apartmentId = apartmentId
    self.name = name
    self.street = street
    self.city = city
  }
}

public struct UploadMediaOutboxPayload: Codable, Equatable, Sendable {
  public let apartmentId: String
  public let mediaId: String

  public init(apartmentId: String, mediaId: String) {
    self.apartmentId = apartmentId
    self.mediaId = mediaId
  }
}

public struct SoftDeleteMediaOutboxPayload: Codable, Equatable, Sendable {
  public let apartmentId: String
  public let mediaId: String

  public init(apartmentId: String, mediaId: String) {
    self.apartmentId = apartmentId
    self.mediaId = mediaId
  }
}

public struct CreateEntryOutboxPayload: Codable, Equatable, Sendable {
  public let apartmentId: String
  public let mediaId: String
  public let entryId: String
  public let text: String
  public let markers: [MarkerPoint]

  public init(
    apartmentId: String,
    mediaId: String,
    entryId: String,
    text: String,
    markers: [MarkerPoint]
  ) {
    self.apartmentId = apartmentId
    self.mediaId = mediaId
    self.entryId = entryId
    self.text = text
    self.markers = markers
  }
}

public struct RetractEntryOutboxPayload: Codable, Equatable, Sendable {
  public let apartmentId: String
  public let mediaId: String
  public let entryId: String

  public init(apartmentId: String, mediaId: String, entryId: String) {
    self.apartmentId = apartmentId
    self.mediaId = mediaId
    self.entryId = entryId
  }
}

public enum OutboxPayloadCodec: Sendable {
  public static func encode<T: Encodable>(_ payload: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(payload)
    guard let json = String(data: data, encoding: .utf8) else {
      throw AppDatabaseError.invalidPayloadEncoding(String(describing: T.self))
    }
    return json
  }

  public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(type, from: data)
  }
}
