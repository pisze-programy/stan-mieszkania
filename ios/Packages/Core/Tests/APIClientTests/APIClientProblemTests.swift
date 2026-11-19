import APIClient
import Domain
import Foundation
import OpenAPIRuntime
import Testing

@Suite("APIClient RFC 9457 ProblemDetails Decoding Tests")
struct APIClientProblemTests {
  @Test("Decodes 409 QUOTA_EXCEEDED into typed APIProblemError")
  func decodesQuotaExceededProblem() async throws {
    let transport = MockClientTransport { _ in
      MockClientTransport.jsonResponse(
        statusCode: MockTransportConstants.statusConflict,
        contentType: "application/problem+json",
        json: """
          {
            "type": "https://api.stanmieszkania.pl/errors/QUOTA_EXCEEDED",
            "title": "Quota exceeded",
            "status": 409,
            "detail": "Apartment reached 250 cloud media limit",
            "code": "QUOTA_EXCEEDED",
            "requestId": "\(MockTransportConstants.requestId)"
          }
          """
      )
    }

    let baseURL = try #require(URL(string: MockTransportConstants.baseURLString))
    let client = APIClient.live(serverURL: baseURL, transport: transport, tokenProvider: { "tok" })

    let sha = String(repeating: "a", count: ContractConstants.sha256HexLength)
    do {
      _ = try await client.initMediaUpload(
        InitMediaUploadInput(
          apartmentId: MockTransportConstants.apartmentId,
          mediaId: MockTransportConstants.mediaId,
          source: .camera,
          sha256: sha,
          capturedAt: MockTransportConstants.sampleDate,
          capturedTz: "Europe/Warsaw",
          capturedAtFromImport: false,
          width: MockTransportConstants.width,
          height: MockTransportConstants.height,
          bytes: MockTransportConstants.bytes
        )
      )
      Issue.record("Expected APIProblemError for QUOTA_EXCEEDED")
    } catch let error as APIProblemError {
      #expect(error.status == MockTransportConstants.statusConflict)
      #expect(error.code == .known(.quotaExceeded))
      #expect(error.isQuotaExceeded)
      #expect(!error.isUpdateRequired)
      #expect(error.requestId == MockTransportConstants.requestId)
    }
  }

  @Test("Decodes undocumented 426 APP_UPDATE_REQUIRED problem+json response")
  func decodesUpgradeRequiredProblem() async throws {
    let transport = MockClientTransport { _ in
      MockClientTransport.jsonResponse(
        statusCode: MockTransportConstants.statusUpgradeRequired,
        contentType: "application/problem+json",
        json: """
          {
            "type": "https://api.stanmieszkania.pl/errors/APP_UPDATE_REQUIRED",
            "title": "App update required",
            "status": 426,
            "detail": "Please update StanMieszkania",
            "code": "APP_UPDATE_REQUIRED",
            "requestId": "\(MockTransportConstants.requestId)"
          }
          """
      )
    }

    let baseURL = try #require(URL(string: MockTransportConstants.baseURLString))
    let client = APIClient.live(serverURL: baseURL, transport: transport, tokenProvider: { "tok" })

    do {
      _ = try await client.listApartments()
      Issue.record("Expected APIProblemError for 426 APP_UPDATE_REQUIRED")
    } catch let error as APIProblemError {
      #expect(error.status == MockTransportConstants.statusUpgradeRequired)
      #expect(error.code == .known(.appUpdateRequired))
      #expect(error.isUpdateRequired)
    }
  }

  @Test("Decodes unknown future additive server error codes without failing")
  func decodesUnknownServerErrorCode() async throws {
    let transport = MockClientTransport { _ in
      MockClientTransport.jsonResponse(
        statusCode: MockTransportConstants.statusBadRequest,
        contentType: "application/problem+json",
        json: """
          {
            "type": "https://api.stanmieszkania.pl/errors/NEW_SERVER_ERROR",
            "title": "Future error",
            "status": 400,
            "detail": "Added in newer backend deployment",
            "code": "NEW_SERVER_ERROR",
            "requestId": "\(MockTransportConstants.requestId)"
          }
          """
      )
    }

    let baseURL = try #require(URL(string: MockTransportConstants.baseURLString))
    let client = APIClient.live(serverURL: baseURL, transport: transport, tokenProvider: { "tok" })

    do {
      _ = try await client.getApartment(MockTransportConstants.apartmentId)
      Issue.record("Expected APIProblemError for NEW_SERVER_ERROR")
    } catch let error as APIProblemError {
      #expect(error.status == MockTransportConstants.statusBadRequest)
      #expect(error.code == .unknown("NEW_SERVER_ERROR"))
      #expect(error.detail == "Added in newer backend deployment")
    }
  }
}
