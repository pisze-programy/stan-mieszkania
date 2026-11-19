import Foundation
import HTTPTypes
import OpenAPIRuntime
import Synchronization

struct RecordedHTTPRequest: Sendable {
  let method: HTTPRequest.Method
  let path: String?
  let headerFields: HTTPFields
  let body: Data?
}

final class MockClientTransport: ClientTransport, Sendable {
  typealias Handler = @Sendable (RecordedHTTPRequest) async throws -> (HTTPResponse, HTTPBody?)

  private let handler: Handler
  private let recordedStorage: Mutex<[RecordedHTTPRequest]> = Mutex([])

  init(handler: @escaping Handler) {
    self.handler = handler
  }

  var recordedRequests: [RecordedHTTPRequest] {
    recordedStorage.withLock { $0 }
  }

  func send(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String
  ) async throws -> (HTTPResponse, HTTPBody?) {
    let bodyData: Data?
    if let body {
      bodyData = try await Data(collecting: body, upTo: MockTransportConstants.maxBodyBytes)
    } else {
      bodyData = nil
    }
    let recorded = RecordedHTTPRequest(
      method: request.method,
      path: request.path,
      headerFields: request.headerFields,
      body: bodyData
    )
    recordedStorage.withLock { $0.append(recorded) }
    return try await handler(recorded)
  }

  static func jsonResponse(
    statusCode: Int,
    contentType: String = "application/json",
    json: String
  ) -> (HTTPResponse, HTTPBody?) {
    var headers = HTTPFields()
    if let contentTypeHeader = HTTPField.Name("Content-Type") {
      headers[contentTypeHeader] = contentType
    }
    let response = HTTPResponse(
      status: .init(code: statusCode),
      headerFields: headers
    )
    return (response, HTTPBody(json))
  }
}

enum MockTransportConstants: Sendable {
  static let maxBodyBytes: Int = 1_048_576
  static let statusOK: Int = 200
  static let statusConflict: Int = 409
  static let statusUpgradeRequired: Int = 426
  static let statusBadRequest: Int = 400
  static let baseURLString: String = "https://api.stanmieszkania.local"
  static let appVersion: String = "1.2.3"
  static let requestId: String = "01933e2a-7b40-7000-8000-000000000900"
  static let apartmentId: String = "01933e2a-7b40-7000-8000-000000000010"
  static let ownerId: String = "01933e2a-7b40-7000-8000-000000000001"
  static let mediaId: String = "01933e2a-7b40-7000-8000-000000000020"
  static let entryId: String = "01933e2a-7b40-7000-8000-000000000030"
  static let markerId: String = "01933e2a-7b40-7000-8000-000000000040"
  static let width: Int = 1_600
  static let height: Int = 1_200
  static let bytes: Int = 240_000
  static let cloudQuota: Int = 250
  static let jpegMaxDim: Int = 3_000
  static let jpegMaxBytes: Int = 3_145_728
  static let jpegQuality: Double = 0.8
  static let markerNumberTwo: Int = 2
  static let coordX: Double = 0.3
  static let coordY: Double = 0.6
  static let seqFive: Int = 5
  static let pageLimit: Int = 20
  static let sampleEpoch: TimeInterval = 1_730_000_000
  static let sampleDate = Date(timeIntervalSince1970: sampleEpoch)
}
