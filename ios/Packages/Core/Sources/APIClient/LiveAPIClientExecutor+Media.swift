import Domain
import Foundation
import OpenAPIRuntime

extension LiveAPIClientExecutor {
  func initMediaUpload(_ request: InitMediaUploadInput) async throws -> InitMediaUploadResult {
    let body = Components.Schemas.InitMediaUploadRequest(
      kind: request.kind == .photo ? .photo : .video,
      source: request.source == .camera ? .camera : ._import,
      sha256: request.sha256,
      capturedAt: request.capturedAt,
      capturedTz: request.capturedTz,
      capturedAtFromImport: request.capturedAtFromImport,
      width: request.width,
      height: request.height,
      bytes: request.bytes,
      lat: request.location?.lat,
      lng: request.location?.lng,
      accuracyM: request.location?.accuracyM,
      locationSource: request.location.map { $0.locationSource == .device ? .device : .exif }
    )
    let input = Operations.initMediaUpload.Input(
      path: .init(apartmentId: request.apartmentId, mediaId: request.mediaId),
      body: .json(body)
    )
    switch try await client.initMediaUpload(input) {
    case .ok(let res):
      return try MediaAndEntryMappers.mapInitMediaResponse(try res.body.json)
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

  func confirmMediaUpload(apartmentId: String, mediaId: String) async throws -> MediaItem {
    let input = Operations.confirmMediaUpload.Input(
      path: .init(apartmentId: apartmentId, mediaId: mediaId)
    )
    switch try await client.confirmMediaUpload(input) {
    case .ok(let res):
      return MediaAndEntryMappers.mapMedia(try res.body.json)
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

  func listApartmentMedia(
    apartmentId: String,
    after: String?,
    limit: Int?
  ) async throws -> MediaTimelinePage {
    let input = Operations.listApartmentMedia.Input(
      path: .init(apartmentId: apartmentId),
      query: .init(after: after, limit: limit)
    )
    switch try await client.listApartmentMedia(input) {
    case .ok(let res):
      let page = try res.body.json
      return MediaTimelinePage(
        items: page.items.map(MediaAndEntryMappers.mapMediaWithAuthor),
        nextCursor: page.nextCursor,
        hasMore: page.hasMore
      )
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

  func getMedia(apartmentId: String, mediaId: String) async throws -> MediaItem {
    let input = Operations.getMedia.Input(path: .init(apartmentId: apartmentId, mediaId: mediaId))
    switch try await client.getMedia(input) {
    case .ok(let res):
      return MediaAndEntryMappers.mapMediaWithAuthor(try res.body.json)
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

  func getMediaDownloadUrl(apartmentId: String, mediaId: String) async throws -> PresignedURLInfo {
    let input = Operations.getMediaDownloadUrl.Input(
      path: .init(apartmentId: apartmentId, mediaId: mediaId)
    )
    switch try await client.getMediaDownloadUrl(input) {
    case .ok(let res):
      return try MediaAndEntryMappers.mapPresignedURL(try res.body.json)
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
    case .internalServerError(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .undocumented(let status, let payload):
      throw await ProblemResponseMapper.mapUndocumented(statusCode: status, payload: payload)
    }
  }

  func softDeleteMedia(apartmentId: String, mediaId: String) async throws -> MediaItem {
    let input = Operations.softDeleteMedia.Input(
      path: .init(apartmentId: apartmentId, mediaId: mediaId)
    )
    switch try await client.softDeleteMedia(input) {
    case .ok(let res):
      return MediaAndEntryMappers.mapMedia(try res.body.json)
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
    case .internalServerError(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .undocumented(let status, let payload):
      throw await ProblemResponseMapper.mapUndocumented(statusCode: status, payload: payload)
    }
  }
}
