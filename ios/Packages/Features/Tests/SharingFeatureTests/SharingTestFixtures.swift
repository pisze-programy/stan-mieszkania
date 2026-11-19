import Domain
import Foundation

enum SharingTestFixtures {
  static let ownerId = "01933e2a-7b40-7000-8000-000000000001"
  static let contributorId = "01933e2a-7b40-7000-8000-000000000002"
  static let apartmentId = "01933e2a-7b40-7000-8000-000000000010"
  static let outboxId = "01933e2a-7b40-7000-8000-000000000020"
  private static let baseTimestamp: TimeInterval = 1_700_000_000
  private static let revokeTimestamp: TimeInterval = 1_700_000_300
  static let baseDate = Date(timeIntervalSince1970: baseTimestamp)
  static let revokeDate = Date(timeIntervalSince1970: revokeTimestamp)
  static let forbiddenStatus = 403

  static let ownerMember = ApartmentMember(
    userId: ownerId,
    displayName: "Jan Kowalski",
    shortTag: "A1B2",
    color: "#007AFF",
    role: .owner,
    joinedAt: baseDate
  )

  static let contributorMember = ApartmentMember(
    userId: contributorId,
    displayName: "Anna Nowak",
    shortTag: "C3D4",
    color: "#34C759",
    role: .contributor,
    joinedAt: baseDate
  )

  static let revokedContributor = ApartmentMember(
    userId: contributorId,
    displayName: "Anna Nowak",
    shortTag: "C3D4",
    color: "#34C759",
    role: .contributor,
    joinedAt: baseDate,
    leftAt: revokeDate
  )

  static let pendingApartment = Apartment(
    id: apartmentId,
    ownerId: ownerId,
    name: "Mieszkanie Centrum",
    street: "Marszałkowska 1",
    city: "Warszawa",
    role: .owner,
    inviteCode: nil,
    shouldSuggestInviteCodeReset: false,
    createdAt: baseDate,
    updatedAt: baseDate
  )

  static let syncedApartment = Apartment(
    id: apartmentId,
    ownerId: ownerId,
    name: "Mieszkanie Centrum",
    street: "Marszałkowska 1",
    city: "Warszawa",
    role: .owner,
    inviteCode: "K7QM-4XPB",
    shouldSuggestInviteCodeReset: true,
    createdAt: baseDate,
    updatedAt: baseDate
  )

  static let resetApartment = Apartment(
    id: apartmentId,
    ownerId: ownerId,
    name: "Mieszkanie Centrum",
    street: "Marszałkowska 1",
    city: "Warszawa",
    role: .owner,
    inviteCode: "M9TR-7WXZ",
    shouldSuggestInviteCodeReset: false,
    createdAt: baseDate,
    updatedAt: baseDate
  )
}
