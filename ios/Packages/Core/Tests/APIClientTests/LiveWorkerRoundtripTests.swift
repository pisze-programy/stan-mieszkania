import APIClient
import CryptoKit
import Domain
import Foundation
import Testing

private enum LiveWorkerConstants: Sendable {
  static let envVarName = "LIVE_WORKER_BASE_URL"
  static let landlordToken = "dev:live-swift-landlord:Jan"
  static let tenantToken = "dev:live-swift-tenant:Anna"
  static let expectedCloudQuota = 250
  static let expectedMinAppVersion = "1.0.0"
  static let sampleJpegBase64 = "/9j/4AAQSkZJRgAB/9k="
  static let widthPx = 1_600
  static let heightPx = 1_200
  static let markerNumberTwo = 2
  static let markerNumberThree = 3
  static let coordFirst = 0.25
  static let coordSecond = 0.5
  static let coordThird = 0.75
  static let syncLimit = 100
  static let httpStatusOK = 200
  static let httpStatusNoContent = 204
  static let requiredEntityTypes: Set<String> = ["apartment", "membership", "media", "entry"]
}

@Suite("Live Swift-to-Worker Roundtrip Tests")
struct LiveWorkerRoundtripTests {
  @Test("Exercises real OpenAPI client over HTTP against local Cloudflare Worker")
  func executesFullLandlordAndTenantJourneyOverLiveHTTP() async throws {
    guard let rawURL = ProcessInfo.processInfo.environment[LiveWorkerConstants.envVarName],
      !rawURL.isEmpty
    else {
      return
    }

    let baseURL = try #require(URL(string: rawURL))
    let landlord = APIClient.live(
      serverURL: baseURL,
      tokenProvider: { LiveWorkerConstants.landlordToken }
    )
    let tenant = APIClient.live(
      serverURL: baseURL,
      tokenProvider: { LiveWorkerConstants.tenantToken }
    )

    let config = try await landlord.getPublicConfig()
    #expect(config.cloudMediaQuotaPerApartment == LiveWorkerConstants.expectedCloudQuota)
    #expect(config.minSupportedAppVersion == LiveWorkerConstants.expectedMinAppVersion)

    let profile = try await landlord.getMyProfile()
    #expect(profile.displayName == "Jan")

    let apartmentId = UUIDv7.generateNow()
    let createdApartment = try await landlord.putApartment(
      UpsertApartmentInput(
        apartmentId: apartmentId,
        name: "Mieszkanie Live E2E",
        street: "Marszalkowska 10",
        city: "Warszawa"
      )
    )
    #expect(createdApartment.id == apartmentId)
    let inviteCode = try #require(createdApartment.inviteCode)

    let mediaId = try await uploadAndConfirmPhoto(
      client: landlord,
      apartmentId: apartmentId,
      baseURL: baseURL
    )
    try await verifyMarkerNumberingAndSync(
      landlord: landlord,
      tenant: tenant,
      apartmentId: apartmentId,
      mediaId: mediaId,
      inviteCode: inviteCode
    )
  }

  private func uploadAndConfirmPhoto(
    client: APIClient,
    apartmentId: String,
    baseURL: URL
  ) async throws -> String {
    let jpegData = try #require(Data(base64Encoded: LiveWorkerConstants.sampleJpegBase64))
    let expectedSha = SHA256.hash(data: jpegData).map { String(format: "%02x", $0) }.joined()
    let mediaId = UUIDv7.generateNow()

    let initResult = try await client.initMediaUpload(
      InitMediaUploadInput(
        apartmentId: apartmentId,
        mediaId: mediaId,
        kind: .photo,
        source: .camera,
        sha256: expectedSha,
        capturedAt: Date(),
        capturedTz: "Europe/Warsaw",
        capturedAtFromImport: false,
        width: LiveWorkerConstants.widthPx,
        height: LiveWorkerConstants.heightPx,
        bytes: jpegData.count
      )
    )
    let uploadInfo = try #require(initResult.upload)
    let resolvedUploadURL = try resolveUploadURL(uploadInfo.url, baseURL: baseURL)
    try await uploadJpegBytes(jpegData, to: resolvedUploadURL)

    let confirmedMedia = try await client.confirmMediaUpload(apartmentId, mediaId)
    #expect(confirmedMedia.syncState == .verified)
    #expect(confirmedMedia.sha256 == expectedSha)
    return mediaId
  }

  private func verifyMarkerNumberingAndSync(
    landlord: APIClient,
    tenant: APIClient,
    apartmentId: String,
    mediaId: String,
    inviteCode: String
  ) async throws {
    let landlordMarkers = [
      makeMarker(1, coord: LiveWorkerConstants.coordFirst),
      makeMarker(LiveWorkerConstants.markerNumberTwo, coord: LiveWorkerConstants.coordSecond),
    ]
    let landlordEntry = try await landlord.putMediaEntry(
      PutMediaEntryInput(
        apartmentId: apartmentId,
        mediaId: mediaId,
        entryId: UUIDv7.generateNow(),
        text: "Sciana [1] i podloga [2]",
        createdAt: Date(),
        markers: landlordMarkers
      )
    )
    #expect(landlordEntry.markers.map(\.number) == [1, LiveWorkerConstants.markerNumberTwo])

    let joinedApartment = try await tenant.joinApartmentByCode(inviteCode)
    #expect(joinedApartment.id == apartmentId)
    #expect(joinedApartment.inviteCode == nil)

    let tenantEntry = try await tenant.putMediaEntry(
      PutMediaEntryInput(
        apartmentId: apartmentId,
        mediaId: mediaId,
        entryId: UUIDv7.generateNow(),
        text: "Rysa [1]",
        createdAt: Date(),
        markers: [makeMarker(1, coord: LiveWorkerConstants.coordThird)]
      )
    )
    #expect(tenantEntry.text == "Rysa [3]")
    #expect(tenantEntry.markers.map(\.number) == [LiveWorkerConstants.markerNumberThree])
    let allServerAssigned = tenantEntry.markers.allSatisfy(\.isServerAssigned)
    #expect(allServerAssigned)

    let changesPage = try await tenant.listApartmentChanges(
      apartmentId,
      0,
      LiveWorkerConstants.syncLimit
    )
    let entityTypes = Set(changesPage.changes.map(\.entityType))
    #expect(LiveWorkerConstants.requiredEntityTypes.isSubset(of: entityTypes))
    let nextSeq = try #require(changesPage.nextSeq)
    #expect(nextSeq > 0)
  }

  private func makeMarker(_ localNumber: Int, coord: Double) -> DraftMarkerInput {
    DraftMarkerInput(id: UUIDv7.generateNow(), localNumber: localNumber, x: coord, y: coord)
  }

  private func resolveUploadURL(_ uploadURL: URL, baseURL: URL) throws -> URL {
    if uploadURL.scheme != nil {
      return uploadURL
    }
    return try #require(URL(string: uploadURL.relativeString, relativeTo: baseURL)?.absoluteURL)
  }

  private func uploadJpegBytes(_ data: Data, to url: URL) async throws {
    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
    request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")

    let (_, response) = try await URLSession.shared.upload(for: request, from: data)
    let httpResponse = try #require(response as? HTTPURLResponse)
    let validStatuses = [LiveWorkerConstants.httpStatusOK, LiveWorkerConstants.httpStatusNoContent]
    #expect(validStatuses.contains(httpResponse.statusCode))
  }
}
