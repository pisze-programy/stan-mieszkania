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

  private static func makeClient(executor: LiveAPIClientExecutor) -> Self {
    Self(
      getPublicConfig: { try await executor.getPublicConfig() },
      getMyProfile: { try await executor.getMyProfile() },
      updateMyProfile: { try await executor.updateMyProfile(displayName: $0) },
      deleteMyAccount: { try await executor.deleteMyAccount(appleAuthorizationCode: $0) },
      putApartment: { try await executor.putApartment($0) },
      listApartments: { try await executor.listApartments() },
      getApartment: { try await executor.getApartment(apartmentId: $0) },
      updateApartment: { try await executor.updateApartment($0) },
      resetApartmentInviteCode: { try await executor.resetApartmentInviteCode(apartmentId: $0) },
      deleteOrLeaveApartment: { try await executor.deleteOrLeaveApartment(apartmentId: $0) },
      listApartmentHistory: { try await executor.listApartmentHistory(apartmentId: $0) },
      joinApartmentByCode: { try await executor.joinApartmentByCode(inviteCode: $0) },
      listApartmentMembers: { try await executor.listApartmentMembers(apartmentId: $0) },
      revokeApartmentMember: {
        try await executor.revokeApartmentMember(apartmentId: $0, userId: $1)
      },
      leaveApartment: { try await executor.leaveApartment(apartmentId: $0) },
      initMediaUpload: { try await executor.initMediaUpload($0) },
      confirmMediaUpload: { try await executor.confirmMediaUpload(apartmentId: $0, mediaId: $1) },
      listApartmentMedia: {
        try await executor.listApartmentMedia(apartmentId: $0, after: $1, limit: $2)
      },
      getMedia: { try await executor.getMedia(apartmentId: $0, mediaId: $1) },
      getMediaDownloadUrl: {
        try await executor.getMediaDownloadUrl(apartmentId: $0, mediaId: $1)
      },
      softDeleteMedia: { try await executor.softDeleteMedia(apartmentId: $0, mediaId: $1) },
      putMediaEntry: { try await executor.putMediaEntry($0) },
      listMediaEntries: { try await executor.listMediaEntries(apartmentId: $0, mediaId: $1) },
      retractMediaEntry: {
        try await executor.retractMediaEntry(apartmentId: $0, mediaId: $1, entryId: $2)
      },
      listApartmentChanges: {
        try await executor.listApartmentChanges(apartmentId: $0, after: $1, limit: $2)
      },
      listMyApartmentsSync: { try await executor.listMyApartmentsSync() }
    )
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
