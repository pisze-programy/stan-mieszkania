export {
  APPLE_AUTH_CODE_MAX_LENGTH,
  APPLE_AUTH_CODE_MIN_LENGTH,
} from './domain/account-deletion.constants';
export {
  ACCOUNT_DELETION_ERROR_CODES,
  accountDeletionFailedError,
  externalAuthCleanupFailedError,
  invalidAppleAuthorizationCodeError,
  type AccountDeletionError,
  type AccountDeletionErrorCode,
} from './domain/account-deletion.errors';
export type {
  AppleTokenRevokerPort,
  IdentityProviderDeleterPort,
  MediaCleanupPort,
} from './domain/external-auth-cleanup.port';
export type {
  AccountDeletionRepository,
  ActiveApartmentContributor,
  LeaveApartmentAsContributorParams,
  ScheduleOrphanDeleteParams,
  TransferApartmentOwnershipParams,
  UserApartmentContext,
} from './domain/account-deletion.repository';
export {
  createDeleteMyAccountUseCase,
  type DeleteMyAccountCommand,
  type DeleteMyAccountDeps,
  type DeleteMyAccountOutcome,
  type DeleteMyAccountUseCase,
} from './application/delete-my-account.use-case';
export { createD1AccountDeletionRepository } from './infrastructure/d1-account-deletion.repository';
export {
  createDirectR2MediaCleanup,
  createFailClosedAppleTokenRevoker,
  createFailClosedIdentityProviderDeleter,
  createLocalAppleTokenRevoker,
  createLocalIdentityProviderDeleter,
  type R2ObjectDeleterLike,
} from './infrastructure/local-external-auth-cleanup';
export {
  createAppleAuthRevoker,
  type AppleAuthRevokerDeps,
  type ExternalAuthFetchFn,
} from './infrastructure/apple-auth-revoker';
export {
  createFirebaseIdentityDeleter,
  type FirebaseIdentityDeleterDeps,
} from './infrastructure/firebase-identity-deleter';
export {
  DeleteAccountRequestSchema,
  type DeleteAccountRequestDto,
} from './http/account-deletion.schema';
export { createAccountDeletionRoutes, deleteMeRoute } from './http/account-deletion.routes';
export {
  InMemoryAccountDeletionRepository,
  RecordingAppleTokenRevoker,
  RecordingIdentityProviderDeleter,
  RecordingMediaCleanup,
} from './testing/in-memory-account-deletion.doubles';
