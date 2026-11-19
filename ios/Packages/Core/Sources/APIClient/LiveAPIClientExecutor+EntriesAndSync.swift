import Domain
import Foundation
import OpenAPIRuntime

extension LiveAPIClientExecutor {
  func putMediaEntry(_ request: PutMediaEntryInput) async throws -> EntryItem {
    let wireMarkers = request.markers.map {
      Components.Schemas.DraftMarker(id: $0.id, localNumber: $0.localNumber, x: $0.x, y: $0.y)
    }
    let input = Operations.putMediaEntry.Input(
      path: .init(
        apartmentId: request.apartmentId,
        mediaId: request.mediaId,
        entryId: request.entryId
      ),
      body: .json(
        .init(
          text: request.text,
          createdAt: request.createdAt,
          markers: wireMarkers
        )
      )
    )
    switch try await client.putMediaEntry(input) {
    case .ok(let res):
      return MediaAndEntryMappers.mapEntry(try res.body.json)
    case .badRequest(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .unauthorized(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .forbidden(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .notFound(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .conflict(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .unprocessableContent(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .internalServerError(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .undocumented(let status, let payload):
      throw await ProblemResponseMapper.mapUndocumented(statusCode: status, payload: payload)
    }
  }

  func listMediaEntries(apartmentId: String, mediaId: String) async throws -> [EntryItem] {
    let input = Operations.listMediaEntries.Input(
      path: .init(apartmentId: apartmentId, mediaId: mediaId)
    )
    switch try await client.listMediaEntries(input) {
    case .ok(let res):
      return try res.body.json.items.map(MediaAndEntryMappers.mapEntry)
    case .badRequest(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .unauthorized(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .forbidden(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .notFound(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .internalServerError(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .undocumented(let status, let payload):
      throw await ProblemResponseMapper.mapUndocumented(statusCode: status, payload: payload)
    }
  }

  func retractMediaEntry(
    apartmentId: String,
    mediaId: String,
    entryId: String
  ) async throws -> EntryItem {
    let input = Operations.retractMediaEntry.Input(
      path: .init(apartmentId: apartmentId, mediaId: mediaId, entryId: entryId)
    )
    switch try await client.retractMediaEntry(input) {
    case .ok(let res):
      return MediaAndEntryMappers.mapEntry(try res.body.json)
    case .badRequest(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .unauthorized(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .forbidden(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .notFound(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .internalServerError(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .undocumented(let status, let payload):
      throw await ProblemResponseMapper.mapUndocumented(statusCode: status, payload: payload)
    }
  }

  func listApartmentChanges(
    apartmentId: String,
    after: Int?,
    limit: Int?
  ) async throws -> APISyncChangesPage {
    let input = Operations.listApartmentChanges.Input(
      path: .init(apartmentId: apartmentId),
      query: .init(after: after, limit: limit)
    )
    switch try await client.listApartmentChanges(input) {
    case .ok(let res):
      return SyncSchemaMappers.mapChangesResponse(try res.body.json)
    case .badRequest(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .unauthorized(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .forbidden(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .notFound(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .unprocessableContent(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .internalServerError(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .undocumented(let status, let payload):
      throw await ProblemResponseMapper.mapUndocumented(statusCode: status, payload: payload)
    }
  }

  func listMyApartmentsSync() async throws -> [APIMyApartmentSyncSummary] {
    switch try await client.listMyApartmentsSync() {
    case .ok(let res):
      return try res.body.json.items.map(SyncSchemaMappers.mapMyApartmentSummary)
    case .unauthorized(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .forbidden(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .internalServerError(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .undocumented(let status, let payload):
      throw await ProblemResponseMapper.mapUndocumented(statusCode: status, payload: payload)
    }
  }
}
