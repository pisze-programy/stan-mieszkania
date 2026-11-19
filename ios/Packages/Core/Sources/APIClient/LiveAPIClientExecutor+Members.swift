import Domain
import Foundation
import OpenAPIRuntime

extension LiveAPIClientExecutor {
  func joinApartmentByCode(inviteCode: String) async throws -> Apartment {
    let input = Operations.joinApartmentByCode.Input(
      body: .json(.init(inviteCode: inviteCode))
    )
    switch try await client.joinApartmentByCode(input) {
    case .ok(let res):
      return CoreSchemaMappers.mapApartment(try res.body.json)
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
    case .tooManyRequests(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .internalServerError(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .undocumented(let status, let payload):
      throw await ProblemResponseMapper.mapUndocumented(statusCode: status, payload: payload)
    }
  }

  func listApartmentMembers(apartmentId: String) async throws -> [ApartmentMember] {
    let input = Operations.listApartmentMembers.Input(path: .init(apartmentId: apartmentId))
    switch try await client.listApartmentMembers(input) {
    case .ok(let res):
      return try res.body.json.items.map(CoreSchemaMappers.mapApartmentMember)
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

  func revokeApartmentMember(apartmentId: String, userId: String) async throws {
    let input = Operations.revokeApartmentMember.Input(
      path: .init(apartmentId: apartmentId, userId: userId)
    )
    switch try await client.revokeApartmentMember(input) {
    case .noContent:
      return
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

  func leaveApartment(apartmentId: String) async throws {
    let input = Operations.leaveApartment.Input(path: .init(apartmentId: apartmentId))
    switch try await client.leaveApartment(input) {
    case .noContent:
      return
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
