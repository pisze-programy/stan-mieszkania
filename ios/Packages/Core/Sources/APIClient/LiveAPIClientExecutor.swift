import Domain
import Foundation
import OpenAPIRuntime

struct LiveAPIClientExecutor: Sendable {
  let client: Client

  func getPublicConfig() async throws -> AppRuntimeConfig {
    let output = try await client.getPublicConfig()
    switch output {
    case .ok(let response):
      return CoreSchemaMappers.mapConfig(try response.body.json)
    case .undocumented(let status, let payload):
      throw await ProblemResponseMapper.mapUndocumented(statusCode: status, payload: payload)
    }
  }

  func getMyProfile() async throws -> UserProfile {
    let output = try await client.getMyProfile()
    switch output {
    case .ok(let response):
      return CoreSchemaMappers.mapUserProfile(try response.body.json)
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

  func updateMyProfile(displayName: String) async throws -> UserProfile {
    let input = Operations.updateMyProfile.Input(
      body: .json(.init(displayName: displayName))
    )
    let output = try await client.updateMyProfile(input)
    switch output {
    case .ok(let response):
      return CoreSchemaMappers.mapUserProfile(try response.body.json)
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

  func deleteMyAccount(appleAuthorizationCode: String?) async throws {
    let body = appleAuthorizationCode.map {
      Operations.deleteMyAccount.Input.Body.json(.init(appleAuthorizationCode: $0))
    }
    let output = try await client.deleteMyAccount(.init(body: body))
    switch output {
    case .noContent:
      return
    case .badRequest(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .unauthorized(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .forbidden(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .unprocessableContent(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .internalServerError(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .badGateway(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .undocumented(let status, let payload):
      throw await ProblemResponseMapper.mapUndocumented(statusCode: status, payload: payload)
    }
  }
}
