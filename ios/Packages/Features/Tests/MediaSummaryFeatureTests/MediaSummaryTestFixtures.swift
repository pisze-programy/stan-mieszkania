import ComposableArchitecture
import Database
import Domain
import Foundation
import SQLiteData

@testable import MediaSummaryFeature

enum MediaSummaryTestFixtures {
  static let ownerId = "01933e2a-7b40-7000-8000-000000000001"
  static let apartmentId = "01933e2a-7b40-7000-8000-000000000010"
  static let draftOneId = "01933e2a-7b40-7000-8000-000000000101"
  static let draftTwoId = "01933e2a-7b40-7000-8000-000000000102"
  static let markerOneId = "01933e2a-7b40-7000-8000-000000000201"
  static let markerTwoId = "01933e2a-7b40-7000-8000-000000000202"
  static let entryOneId = "01933e2a-7b40-7000-8000-000000000301"
  static let outboxOneId = "01933e2a-7b40-7000-8000-000000000401"
  static let outboxTwoId = "01933e2a-7b40-7000-8000-000000000402"
  static let outboxThreeId = "01933e2a-7b40-7000-8000-000000000403"

  static let photoWidth = 1_600
  static let photoHeight = 1_200
  static let photoBytes = 320_000
  private static let captureEpoch: TimeInterval = 1_700_000_000
  static let captureDate = Date(timeIntervalSince1970: captureEpoch)
  static let sha256 = String(repeating: "c", count: ContractConstants.sha256HexLength)

  static let author = AuthorSummary(
    userId: ownerId,
    displayName: "Jan Kowalski",
    shortTag: "A1B2",
    color: "#007AFF",
    role: .owner
  )

  static func makeDraft(
    id: String = draftOneId,
    origin: CaptureSourceKind = .camera,
    capturedAtFromImport: Bool = false
  ) -> CapturedPhotoDraft {
    CapturedPhotoDraft(
      id: id,
      apartmentId: apartmentId,
      origin: origin,
      source: origin.mediaSource,
      localFilePath: "/tmp/\(id).jpg",
      sha256: sha256,
      width: photoWidth,
      height: photoHeight,
      bytes: photoBytes,
      capturedAt: captureDate,
      capturedTz: "Europe/Warsaw",
      capturedAtFromImport: capturedAtFromImport,
      location: nil
    )
  }

  static func seedApartmentDatabase() throws -> any DatabaseWriter {
    let database = try makeInMemoryDatabase()
    let apartment = Apartment(
      id: apartmentId,
      ownerId: ownerId,
      name: "Kawalerka Mokotów",
      street: "Puławska 10",
      city: "Warszawa",
      role: .owner,
      createdAt: captureDate,
      updatedAt: captureDate
    )
    try database.write { db in
      try ApartmentRecord.insert { ApartmentRecord(apartment: apartment) }.execute(db)
    }
    return database
  }

  static func makeIDGenerator(_ values: [String]) -> any IDGenerator {
    let queue = LockIsolated(values)
    return ClosureIDGenerator {
      queue.withValue { items in
        items.isEmpty ? UUIDv7.generateNow() : items.removeFirst()
      }
    }
  }
}
