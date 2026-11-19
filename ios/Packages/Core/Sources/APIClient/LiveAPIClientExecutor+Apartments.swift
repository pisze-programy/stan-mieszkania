import Domain
import Foundation
import OpenAPIRuntime

extension LiveAPIClientExecutor {
  func putApartment(_ request: UpsertApartmentInput) async throws -> Apartment {
    let input = Operations.putApartment.Input(
      path: .init(apartmentId: request.apartmentId),
      body: .json(.init(name: request.name, street: request.street, city: request.city))
    )
    switch try await client.putApartment(input) {
    case .ok(let res):
      return CoreSchemaMappers.mapApartment(try res.body.json)
    case .badRequest(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .unauthorized(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .forbidden(let res):
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

  func listApartments() async throws -> [Apartment] {
    switch try await client.listApartments() {
    case .ok(let res):
      return try res.body.json.items.map(CoreSchemaMappers.mapApartment)
    case .unauthorized(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .internalServerError(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .undocumented(let status, let payload):
      throw await ProblemResponseMapper.mapUndocumented(statusCode: status, payload: payload)
    }
  }

  func getApartment(apartmentId: String) async throws -> Apartment {
    switch try await client.getApartment(.init(path: .init(apartmentId: apartmentId))) {
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
    case .internalServerError(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .undocumented(let status, let payload):
      throw await ProblemResponseMapper.mapUndocumented(statusCode: status, payload: payload)
    }
  }

  func updateApartment(_ request: UpdateApartmentInput) async throws -> Apartment {
    let input = Operations.updateApartment.Input(
      path: .init(apartmentId: request.apartmentId),
      body: .json(.init(name: request.name, street: request.street, city: request.city))
    )
    switch try await client.updateApartment(input) {
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
    case .internalServerError(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .undocumented(let status, let payload):
      throw await ProblemResponseMapper.mapUndocumented(statusCode: status, payload: payload)
    }
  }

  func resetApartmentInviteCode(apartmentId: String) async throws -> Apartment {
    let input = Operations.resetApartmentInviteCode.Input(path: .init(apartmentId: apartmentId))
    switch try await client.resetApartmentInviteCode(input) {
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
    case .conflict(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .internalServerError(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .undocumented(let status, let payload):
      throw await ProblemResponseMapper.mapUndocumented(statusCode: status, payload: payload)
    }
  }

  func deleteOrLeaveApartment(apartmentId: String) async throws {
    let input = Operations.deleteOrLeaveApartment.Input(path: .init(apartmentId: apartmentId))
    switch try await client.deleteOrLeaveApartment(input) {
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
    case .internalServerError(let res):
      throw ProblemResponseMapper.map(try res.body.application_problem_plus_json)
    case .undocumented(let status, let payload):
      throw await ProblemResponseMapper.mapUndocumented(statusCode: status, payload: payload)
    }
  }

  func listApartmentHistory(apartmentId: String) async throws -> [ApartmentChange] {
    let input = Operations.listApartmentHistory.Input(path: .init(apartmentId: apartmentId))
    switch try await client.listApartmentHistory(input) {
    case .ok(let res):
      return try res.body.json.items.map(CoreSchemaMappers.mapApartmentChange)
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
}
