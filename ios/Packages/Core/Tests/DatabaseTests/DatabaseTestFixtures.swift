import Database
import Domain
import Foundation

enum DatabaseTestFixtures {
  static let ownerId = "01933e2a-7b40-7000-8000-000000000001"
  static let contributorId = "01933e2a-7b40-7000-8000-000000000002"
  static let apartmentId = "01933e2a-7b40-7000-8000-000000000010"
  static let secondApartmentId = "01933e2a-7b40-7000-8000-000000000011"
  static let mediaId = "01933e2a-7b40-7000-8000-000000000020"
  static let secondMediaId = "01933e2a-7b40-7000-8000-000000000021"
  static let entryId = "01933e2a-7b40-7000-8000-000000000030"
  static let secondEntryId = "01933e2a-7b40-7000-8000-000000000031"
  static let markerOneId = "01933e2a-7b40-7000-8000-000000000040"
  static let markerTwoId = "01933e2a-7b40-7000-8000-000000000041"
  static let outboxOneId = "01933e2a-7b40-7000-8000-000000000050"
  static let outboxTwoId = "01933e2a-7b40-7000-8000-000000000051"
  static let outboxThreeId = "01933e2a-7b40-7000-8000-000000000052"
  static let changeId = "01933e2a-7b40-7000-8000-000000000060"

  static let baseEpochSeconds: TimeInterval = 1_700_000_000
  static let plusOneMinuteSeconds: TimeInterval = 1_700_000_060
  static let plusTwoMinutesSeconds: TimeInterval = 1_700_000_120
  static let plusThreeMinutesSeconds: TimeInterval = 1_700_000_180
  static let plusFiveMinutesSeconds: TimeInterval = 1_700_000_300

  static let baseDate = Date(timeIntervalSince1970: baseEpochSeconds)
  static let plusOneMinute = Date(timeIntervalSince1970: plusOneMinuteSeconds)
  static let plusTwoMinutes = Date(timeIntervalSince1970: plusTwoMinutesSeconds)
  static let plusThreeMinutes = Date(timeIntervalSince1970: plusThreeMinutesSeconds)
  static let plusFiveMinutes = Date(timeIntervalSince1970: plusFiveMinutesSeconds)

  static let sha256 = String(repeating: "a", count: ContractConstants.sha256HexLength)
  static let width = 1_600
  static let height = 1_200
  static let bytes = 350_000
  static let localFilePath = "/var/mobile/media/photo-1.jpg"
  static let markerOneNumber = 1
  static let markerTwoNumber = 2
  static let markerThreeNumber = 3
  static let markerFourNumber = 4
  static let coordLow = 0.25
  static let coordMid = 0.5
  static let coordHigh = 0.75
  static let lat = 52.2297
  static let lng = 21.0122
  static let accuracyM = 8.5
  static let cloudCountThree = 3
  static let seqOne = 1
  static let seqTwo = 2
  static let seqThree = 3
  static let seqFour = 4
  static let seqFive = 5
  static let seqSix = 6
  static let expectedCountTwo = 2

  static func makeOwnerProfile() -> UserProfile {
    UserProfile(
      id: ownerId,
      displayName: "Anna Nowak",
      shortTag: "A1B2",
      color: "#007AFF",
      createdAt: baseDate
    )
  }

  static func makeOwnerMember() -> ApartmentMember {
    ApartmentMember(
      userId: ownerId,
      displayName: "Anna Nowak",
      shortTag: "A1B2",
      color: "#007AFF",
      role: .owner,
      joinedAt: baseDate
    )
  }

  static func makeContributorMember(leftAt: Date? = nil) -> ApartmentMember {
    ApartmentMember(
      userId: contributorId,
      displayName: "Jan Kowalski",
      shortTag: "C3D4",
      color: "#34C759",
      role: .contributor,
      joinedAt: plusOneMinute,
      leftAt: leftAt
    )
  }

  static func makeOwnerSummary() -> AuthorSummary {
    AuthorSummary(
      userId: ownerId,
      displayName: "Anna Nowak",
      shortTag: "A1B2",
      color: "#007AFF",
      role: .owner
    )
  }

  static func makeApartment(
    id: String = apartmentId,
    name: String = "Mieszkanie Mokotow",
    street: String = "Pulawska 10",
    city: String = "Warszawa",
    cloudMediaCount: Int = 0
  ) -> Apartment {
    Apartment(
      id: id,
      ownerId: ownerId,
      name: name,
      street: street,
      city: city,
      role: .owner,
      inviteCode: "K7QM4XPB",
      shouldSuggestInviteCodeReset: false,
      cloudMediaCount: cloudMediaCount,
      createdAt: baseDate,
      updatedAt: baseDate
    )
  }

  static func makeMedia(
    id: String = mediaId,
    apartmentId: String = apartmentId,
    authorId: String = ownerId,
    syncState: MediaSyncState = .localOnly,
    serverReceivedAt: Date? = nil,
    localFilePath: String? = localFilePath
  ) -> MediaItem {
    MediaItem(
      id: id,
      apartmentId: apartmentId,
      authorId: authorId,
      kind: .photo,
      source: .camera,
      sha256: sha256,
      capturedAt: baseDate,
      capturedTz: "Europe/Warsaw",
      capturedAtFromImport: false,
      serverReceivedAt: serverReceivedAt,
      width: width,
      height: height,
      bytes: bytes,
      syncState: syncState,
      localFilePath: localFilePath
    )
  }

  static func makeMarker(
    id: String,
    entryId: String = entryId,
    mediaId: String = mediaId,
    number: Int,
    isServerAssigned: Bool = false,
    x: Double = coordLow,
    y: Double = coordHigh
  ) -> MarkerPoint {
    MarkerPoint(
      id: id,
      entryId: entryId,
      mediaId: mediaId,
      number: number,
      isServerAssigned: isServerAssigned,
      x: x,
      y: y
    )
  }

  static func makeEntry(
    id: String = entryId,
    mediaId: String = mediaId,
    authorId: String = ownerId,
    text: String = "Rysa [1] i ubytek [2]",
    markers: [MarkerPoint] = [],
    serverReceivedAt: Date? = nil
  ) -> EntryItem {
    EntryItem(
      id: id,
      mediaId: mediaId,
      authorId: authorId,
      text: text,
      markers: markers,
      createdAt: baseDate,
      serverReceivedAt: serverReceivedAt
    )
  }
}
