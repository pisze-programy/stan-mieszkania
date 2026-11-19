import Foundation
import Testing

@testable import Domain

@Suite("Domain Entities Tests")
struct DomainEntitiesTests {
  private enum Fixtures {
    static let userId = "01933e2a-7b40-7000-8000-000000000001"
    static let apartmentId = "01933e2a-7b40-7000-8000-000000000002"
    static let mediaId = "01933e2a-7b40-7000-8000-000000000003"
    static let entryId = "01933e2a-7b40-7000-8000-000000000004"
    static let markerId = "01933e2a-7b40-7000-8000-000000000005"
    static let changeId = "01933e2a-7b40-7000-8000-000000000006"
    static let sampleDate = Date(timeIntervalSince1970: 1_700_000_000)
    static let laterDate = Date(timeIntervalSince1970: 1_700_000_060)
    static let sha256 = String(repeating: "a", count: ContractConstants.sha256HexLength)
    static let width = 1_200
    static let height = 900
    static let bytes = 240_000
    static let markerX = 0.25
    static let markerY = 0.75
    static let lat = 52.2297
    static let lng = 21.0122
    static let accuracyM = 12.5
    static let cloudCount = 3
  }

  @Test("Maps MediaSource import rawValue cleanly through Codable")
  func mediaSourceCodableMapping() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let importedData = try encoder.encode(MediaSource.imported)
    #expect(String(bytes: importedData, encoding: .utf8) == "\"import\"")
    #expect(try decoder.decode(MediaSource.self, from: importedData) == .imported)

    let cameraData = try encoder.encode(MediaSource.camera)
    #expect(String(bytes: cameraData, encoding: .utf8) == "\"camera\"")
    #expect(try decoder.decode(MediaSource.self, from: cameraData) == .camera)
  }

  @Test("Derives MediaItem verification and soft-delete state from timestamps")
  func mediaItemDerivedState() {
    let localMedia = MediaItem(
      id: Fixtures.mediaId,
      apartmentId: Fixtures.apartmentId,
      authorId: Fixtures.userId,
      kind: .photo,
      source: .camera,
      sha256: Fixtures.sha256,
      capturedAt: Fixtures.sampleDate,
      capturedTz: "Europe/Warsaw",
      capturedAtFromImport: false,
      width: Fixtures.width,
      height: Fixtures.height,
      bytes: Fixtures.bytes,
      syncState: .localOnly
    )
    #expect(!localMedia.isVerified)
    #expect(!localMedia.isSoftDeleted)

    let verifiedDeletedMedia = MediaItem(
      id: Fixtures.mediaId,
      apartmentId: Fixtures.apartmentId,
      authorId: Fixtures.userId,
      kind: .photo,
      source: .imported,
      sha256: Fixtures.sha256,
      capturedAt: Fixtures.sampleDate,
      capturedTz: "Europe/Warsaw",
      capturedAtFromImport: true,
      serverReceivedAt: Fixtures.laterDate,
      width: Fixtures.width,
      height: Fixtures.height,
      bytes: Fixtures.bytes,
      syncState: .softDeleted,
      deletedAt: Fixtures.laterDate,
      deletedBy: Fixtures.userId
    )
    #expect(verifiedDeletedMedia.isVerified)
    #expect(verifiedDeletedMedia.isSoftDeleted)
  }

  @Test("Derives EntryItem verification and retraction state from timestamps")
  func entryItemDerivedState() {
    let marker = MarkerPoint(
      id: Fixtures.markerId,
      entryId: Fixtures.entryId,
      mediaId: Fixtures.mediaId,
      number: DomainConstants.firstMarkerNumber,
      isServerAssigned: false,
      x: Fixtures.markerX,
      y: Fixtures.markerY
    )

    let localEntry = EntryItem(
      id: Fixtures.entryId,
      mediaId: Fixtures.mediaId,
      authorId: Fixtures.userId,
      text: "Rysa na szybie [1]",
      markers: [marker],
      createdAt: Fixtures.sampleDate
    )
    #expect(!localEntry.isVerified)
    #expect(!localEntry.isRetracted)

    let retractedEntry = EntryItem(
      id: Fixtures.entryId,
      mediaId: Fixtures.mediaId,
      authorId: Fixtures.userId,
      text: "Rysa na szybie [1]",
      markers: [marker],
      createdAt: Fixtures.sampleDate,
      serverReceivedAt: Fixtures.laterDate,
      retractedAt: Fixtures.laterDate
    )
    #expect(retractedEntry.isVerified)
    #expect(retractedEntry.isRetracted)
  }

  @Test("Checks ApartmentMember active status and ApartmentChange")
  func membershipAndApartmentChange() {
    let activeMember = ApartmentMember(
      userId: Fixtures.userId,
      displayName: "Jan Kowalski",
      shortTag: "A1B2",
      color: DomainConstants.defaultAuthorColor,
      role: .owner,
      joinedAt: Fixtures.sampleDate
    )
    #expect(activeMember.id == Fixtures.userId)
    #expect(activeMember.isActive)

    let leftMember = ApartmentMember(
      userId: Fixtures.userId,
      displayName: "Jan Kowalski",
      shortTag: "A1B2",
      color: DomainConstants.defaultAuthorColor,
      role: .contributor,
      joinedAt: Fixtures.sampleDate,
      leftAt: Fixtures.laterDate
    )
    #expect(!leftMember.isActive)

    let apartment = Apartment(
      id: Fixtures.apartmentId,
      ownerId: Fixtures.userId,
      name: "Mieszkanie Centrum",
      street: "Marszałkowska 1",
      city: "Warszawa",
      role: .owner,
      inviteCode: "K7QM-4XPB",
      cloudMediaCount: Fixtures.cloudCount,
      createdAt: Fixtures.sampleDate,
      updatedAt: Fixtures.laterDate
    )
    let change = ApartmentChange(
      id: Fixtures.changeId,
      apartmentId: Fixtures.apartmentId,
      authorId: Fixtures.userId,
      field: .street,
      oldValue: "Stara 1",
      newValue: apartment.street,
      createdAt: Fixtures.laterDate
    )
    #expect(change.field == .street)
  }

  @Test("Checks AppRuntimeConfig fallbackDefaults and CaptureLocationMetadata")
  func runtimeConfigAndLocationMetadata() throws {
    let defaults = AppRuntimeConfig.fallbackDefaults
    #expect(defaults.minSupportedAppVersion == ContractConstants.defaultMinSupportedAppVersion)
    #expect(
      defaults.cloudMediaQuotaPerApartment == ContractConstants.defaultCloudMediaQuotaPerApartment
    )
    #expect(defaults.jpegCompression.maxDimensionPx == ContractConstants.defaultJpegMaxDimensionPx)
    #expect(defaults.jpegCompression.quality == ContractConstants.defaultJpegQuality)
    #expect(defaults.jpegCompression.maxBytes == ContractConstants.defaultJpegMaxBytes)

    let location = CaptureLocationMetadata(
      lat: Fixtures.lat,
      lng: Fixtures.lng,
      accuracyM: Fixtures.accuracyM,
      locationSource: .device
    )
    let encodedLocation = try JSONEncoder().encode(location)
    #expect(
      try JSONDecoder().decode(CaptureLocationMetadata.self, from: encodedLocation) == location
    )
  }
}
