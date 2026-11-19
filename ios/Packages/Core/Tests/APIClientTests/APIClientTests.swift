import APIClient
import Domain
import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@Suite("APIClient OpenAPI Round-Trip and Middleware Tests")
struct APIClientTests {
  @Test("Injects Authorization, X-App-Version, and X-Request-Id headers and decodes config")
  func injectsHeadersAndDecodesPublicConfig() async throws {
    let transport = MockClientTransport { _ in
      MockClientTransport.jsonResponse(
        statusCode: MockTransportConstants.statusOK,
        json: APITestJSONFixtures.publicConfigJSON
      )
    }

    let baseURL = try #require(URL(string: MockTransportConstants.baseURLString))
    let client = APIClient.live(
      serverURL: baseURL,
      transport: transport,
      appVersion: MockTransportConstants.appVersion,
      tokenProvider: { "dev:user-1:Anna" },
      requestIdGenerator: { MockTransportConstants.requestId }
    )

    let config = try await client.getPublicConfig()
    #expect(config.minSupportedAppVersion == "1.2.0")
    #expect(config.cloudMediaQuotaPerApartment == MockTransportConstants.cloudQuota)
    #expect(config.jpegCompression.maxDimensionPx == MockTransportConstants.jpegMaxDim)

    let recorded = try #require(transport.recordedRequests.first)
    #expect(recorded.path == "/v1/config")
    #expect(
      recorded.headerFields[try #require(HTTPField.Name("Authorization"))]
        == "Bearer dev:user-1:Anna"
    )
    #expect(
      recorded.headerFields[try #require(HTTPField.Name("X-App-Version"))]
        == MockTransportConstants.appVersion
    )
    #expect(
      recorded.headerFields[try #require(HTTPField.Name("X-Request-Id"))]
        == MockTransportConstants.requestId
    )
  }

  @Test("Round-trips putApartment and putMediaEntry through OpenAPI generated client")
  func roundTripsApartmentAndEntryOperations() async throws {
    let transport = MockClientTransport { request in
      let json =
        request.path?.contains("/entries/") == true
        ? APITestJSONFixtures.entryJSON
        : APITestJSONFixtures.apartmentJSON
      return MockClientTransport.jsonResponse(
        statusCode: MockTransportConstants.statusOK,
        json: json
      )
    }

    let baseURL = try #require(URL(string: MockTransportConstants.baseURLString))
    let client = APIClient.live(serverURL: baseURL, transport: transport, tokenProvider: { "tok" })

    let apartment = try await client.putApartment(
      UpsertApartmentInput(
        apartmentId: MockTransportConstants.apartmentId,
        name: "Mieszkanie Mokotow",
        street: "Pulawska 10",
        city: "Warszawa"
      )
    )
    #expect(apartment.id == MockTransportConstants.apartmentId)
    #expect(apartment.inviteCode == "K7QM4XPB")

    let draftMarker = DraftMarkerInput(
      id: MockTransportConstants.markerId,
      localNumber: 1,
      x: MockTransportConstants.coordX,
      y: MockTransportConstants.coordY
    )
    let entry = try await client.putMediaEntry(
      PutMediaEntryInput(
        apartmentId: MockTransportConstants.apartmentId,
        mediaId: MockTransportConstants.mediaId,
        entryId: MockTransportConstants.entryId,
        text: "Rysa [1]",
        createdAt: MockTransportConstants.sampleDate,
        markers: [draftMarker]
      )
    )
    #expect(entry.text == "Rysa [2]")
    #expect(entry.markers.first?.number == MockTransportConstants.markerNumberTwo)
    #expect(entry.markers.first?.isServerAssigned == true)
  }

  @Test("Decodes hydrated sync changes page with cursor query parameters")
  func decodesHydratedSyncChangesPage() async throws {
    let transport = MockClientTransport { _ in
      MockClientTransport.jsonResponse(
        statusCode: MockTransportConstants.statusOK,
        json: APITestJSONFixtures.syncChangesPageJSON
      )
    }

    let baseURL = try #require(URL(string: MockTransportConstants.baseURLString))
    let client = APIClient.live(serverURL: baseURL, transport: transport, tokenProvider: { "tok" })

    let page = try await client.listApartmentChanges(
      MockTransportConstants.apartmentId,
      0,
      MockTransportConstants.pageLimit
    )
    #expect(page.nextSeq == MockTransportConstants.seqFive)
    #expect(!page.hasMore)
    #expect(page.changes.count == 1)
    #expect(page.changes.first?.seq == MockTransportConstants.seqFive)

    let recordedPath = try #require(transport.recordedRequests.first?.path)
    #expect(recordedPath.contains("after=0"))
    #expect(recordedPath.contains("limit=20"))
  }
}
