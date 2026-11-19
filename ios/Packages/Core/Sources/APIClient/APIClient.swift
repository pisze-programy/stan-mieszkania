import AuthClient
import Dependencies
import DependenciesMacros
import Domain
import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

@DependencyClient
public struct APIClient: Sendable {
  public var getPublicConfig: @Sendable () async throws -> AppRuntimeConfig
  public var getMyProfile: @Sendable () async throws -> UserProfile
  public var updateMyProfile: @Sendable (_ displayName: String) async throws -> UserProfile
  public var deleteMyAccount: @Sendable (_ appleAuthorizationCode: String?) async throws -> Void
  public var putApartment: @Sendable (_ request: UpsertApartmentInput) async throws -> Apartment
  public var listApartments: @Sendable () async throws -> [Apartment]
  public var getApartment: @Sendable (_ apartmentId: String) async throws -> Apartment
  public var updateApartment: @Sendable (_ request: UpdateApartmentInput) async throws -> Apartment
  public var resetApartmentInviteCode: @Sendable (_ apartmentId: String) async throws -> Apartment
  public var deleteOrLeaveApartment: @Sendable (_ apartmentId: String) async throws -> Void
  public var listApartmentHistory:
    @Sendable (_ apartmentId: String) async throws -> [ApartmentChange]
  public var joinApartmentByCode: @Sendable (_ inviteCode: String) async throws -> Apartment
  public var listApartmentMembers:
    @Sendable (_ apartmentId: String) async throws -> [ApartmentMember]
  public var revokeApartmentMember:
    @Sendable (_ apartmentId: String, _ userId: String) async throws -> Void
  public var leaveApartment: @Sendable (_ apartmentId: String) async throws -> Void
  public var initMediaUpload:
    @Sendable (_ request: InitMediaUploadInput) async throws -> InitMediaUploadResult
  public var confirmMediaUpload:
    @Sendable (_ apartmentId: String, _ mediaId: String) async throws -> MediaItem
  public var listApartmentMedia:
    @Sendable (_ apartmentId: String, _ after: String?, _ limit: Int?) async throws ->
      MediaTimelinePage
  public var getMedia:
    @Sendable (_ apartmentId: String, _ mediaId: String) async throws -> MediaItem
  public var getMediaDownloadUrl:
    @Sendable (_ apartmentId: String, _ mediaId: String) async throws -> PresignedURLInfo
  public var softDeleteMedia:
    @Sendable (_ apartmentId: String, _ mediaId: String) async throws -> MediaItem
  public var putMediaEntry: @Sendable (_ request: PutMediaEntryInput) async throws -> EntryItem
  public var listMediaEntries:
    @Sendable (_ apartmentId: String, _ mediaId: String) async throws -> [EntryItem]
  public var retractMediaEntry:
    @Sendable (_ apartmentId: String, _ mediaId: String, _ entryId: String) async throws ->
      EntryItem
  public var listApartmentChanges:
    @Sendable (_ apartmentId: String, _ after: Int?, _ limit: Int?) async throws ->
      APISyncChangesPage
  public var listMyApartmentsSync: @Sendable () async throws -> [APIMyApartmentSyncSummary]

  public static func live(
    serverURL: URL,
    transport: any ClientTransport = URLSessionTransport(),
    appVersion: String = APIClientConstants.defaultAppVersion,
    tokenProvider: @escaping @Sendable () async -> String?,
    requestIdGenerator: @escaping @Sendable () -> String = UUIDv7.generateNow
  ) -> Self {
    let middleware = APIRequestMiddleware(
      tokenProvider: tokenProvider,
      appVersion: appVersion,
      requestIdGenerator: requestIdGenerator
    )
    let generatedClient = Client(
      serverURL: serverURL,
      configuration: .init(dateTranscoder: FlexibleISO8601DateTranscoder()),
      transport: transport,
      middlewares: [middleware]
    )
    let executor = LiveAPIClientExecutor(client: generatedClient)
    return makeClient(executor: executor)
  }

  private static func run<T: Sendable>(_ op: () async throws -> T) async throws -> T {
    try await TransportErrorMapper.run(op)
  }

  private static func makeClient(executor exec: LiveAPIClientExecutor) -> Self {
    var api = Self()
    bindIdentityAndApartmentEndpoints(&api, executor: exec)
    bindMediaAndSyncEndpoints(&api, executor: exec)
    return api
  }

  private static func bindIdentityAndApartmentEndpoints(
    _ api: inout Self,
    executor exec: LiveAPIClientExecutor
  ) {
    api.getPublicConfig = { try await run { try await exec.getPublicConfig() } }
    api.getMyProfile = { try await run { try await exec.getMyProfile() } }
    api.updateMyProfile = { name in
      try await run { try await exec.updateMyProfile(displayName: name) }
    }
    api.deleteMyAccount = { code in
      try await run { try await exec.deleteMyAccount(appleAuthorizationCode: code) }
    }
    api.putApartment = { req in try await run { try await exec.putApartment(req) } }
    api.listApartments = { try await run { try await exec.listApartments() } }
    api.getApartment = { id in try await run { try await exec.getApartment(apartmentId: id) } }
    api.updateApartment = { req in try await run { try await exec.updateApartment(req) } }
    api.resetApartmentInviteCode = { id in
      try await run { try await exec.resetApartmentInviteCode(apartmentId: id) }
    }
    api.deleteOrLeaveApartment = { id in
      try await run { try await exec.deleteOrLeaveApartment(apartmentId: id) }
    }
    api.listApartmentHistory = { id in
      try await run { try await exec.listApartmentHistory(apartmentId: id) }
    }
    api.joinApartmentByCode = { code in
      try await run { try await exec.joinApartmentByCode(inviteCode: code) }
    }
    api.listApartmentMembers = { id in
      try await run { try await exec.listApartmentMembers(apartmentId: id) }
    }
    api.revokeApartmentMember = { aptId, userId in
      try await run { try await exec.revokeApartmentMember(apartmentId: aptId, userId: userId) }
    }
    api.leaveApartment = { id in try await run { try await exec.leaveApartment(apartmentId: id) } }
  }

  private static func bindMediaAndSyncEndpoints(
    _ api: inout Self,
    executor exec: LiveAPIClientExecutor
  ) {
    api.initMediaUpload = { req in try await run { try await exec.initMediaUpload(req) } }
    api.confirmMediaUpload = { aptId, mediaId in
      try await run { try await exec.confirmMediaUpload(apartmentId: aptId, mediaId: mediaId) }
    }
    api.listApartmentMedia = { aptId, after, limit in
      try await run {
        try await exec.listApartmentMedia(apartmentId: aptId, after: after, limit: limit)
      }
    }
    api.getMedia = { aptId, mediaId in
      try await run { try await exec.getMedia(apartmentId: aptId, mediaId: mediaId) }
    }
    api.getMediaDownloadUrl = { aptId, mediaId in
      try await run { try await exec.getMediaDownloadUrl(apartmentId: aptId, mediaId: mediaId) }
    }
    api.softDeleteMedia = { aptId, mediaId in
      try await run { try await exec.softDeleteMedia(apartmentId: aptId, mediaId: mediaId) }
    }
    api.putMediaEntry = { req in try await run { try await exec.putMediaEntry(req) } }
    api.listMediaEntries = { aptId, mediaId in
      try await run { try await exec.listMediaEntries(apartmentId: aptId, mediaId: mediaId) }
    }
    api.retractMediaEntry = { aptId, mediaId, entryId in
      try await run {
        try await exec.retractMediaEntry(apartmentId: aptId, mediaId: mediaId, entryId: entryId)
      }
    }
    api.listApartmentChanges = { aptId, after, limit in
      try await run {
        try await exec.listApartmentChanges(apartmentId: aptId, after: after, limit: limit)
      }
    }
    api.listMyApartmentsSync = { try await run { try await exec.listMyApartmentsSync() } }
  }
}

extension APIClient: DependencyKey {
  public static var liveValue: APIClient {
    guard let serverURL = URL(string: APIClientConstants.defaultBaseURLString) else {
      fatalError("Invalid APIClientConstants.defaultBaseURLString")
    }
    return .live(
      serverURL: serverURL,
      tokenProvider: {
        @Dependency(\.authClient) var authClient
        return try? await authClient.validBearerToken()
      }
    )
  }

  public static var testValue: APIClient {
    APIClient()
  }
}

extension DependencyValues {
  public var apiClient: APIClient {
    get { self[APIClient.self] }
    set { self[APIClient.self] = newValue }
  }
}
