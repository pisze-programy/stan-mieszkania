import Database
import Domain
import Foundation
import Testing

@Suite("Database Record Mapper Tests")
struct RecordMapperTests {
  @Test("Round-trips Domain entities cleanly through Table records and mappers")
  func domainRecordMappersRoundTrip() throws {
    let profile = DatabaseTestFixtures.makeOwnerProfile()
    #expect(LocalUserRecord(profile: profile).toDomain() == profile)

    let apartment = DatabaseTestFixtures.makeApartment()
    #expect(try ApartmentRecord(apartment: apartment).toDomain() == apartment)

    let change = ApartmentChange(
      id: DatabaseTestFixtures.changeId,
      apartmentId: DatabaseTestFixtures.apartmentId,
      authorId: DatabaseTestFixtures.ownerId,
      field: .name,
      oldValue: "Old",
      newValue: "New",
      createdAt: DatabaseTestFixtures.baseDate
    )
    #expect(try ApartmentChangeRecord(change: change).toDomain() == change)

    let member = DatabaseTestFixtures.makeContributorMember()
    let memberRecord = MemberRecord(apartmentId: DatabaseTestFixtures.apartmentId, member: member)
    #expect(try memberRecord.toDomain() == member)
    #expect(try memberRecord.toAuthorSummary().userId == member.userId)

    let location = CaptureLocationMetadata(
      lat: DatabaseTestFixtures.lat,
      lng: DatabaseTestFixtures.lng,
      accuracyM: DatabaseTestFixtures.accuracyM,
      locationSource: .device
    )
    let media = DatabaseTestFixtures.makeMedia()
    let mediaRecord = MediaRecord(item: media, location: location)
    #expect(mediaRecord.captureLocation == location)
    #expect(try mediaRecord.toDomain() == media)

    let marker = DatabaseTestFixtures.makeMarker(
      id: DatabaseTestFixtures.markerOneId,
      number: DatabaseTestFixtures.markerOneNumber
    )
    #expect(MarkerRecord(marker: marker).toDomain() == marker)

    let entry = DatabaseTestFixtures.makeEntry(markers: [marker])
    #expect(EntryRecord(item: entry).toDomain(markers: [marker]) == entry)
  }
}
