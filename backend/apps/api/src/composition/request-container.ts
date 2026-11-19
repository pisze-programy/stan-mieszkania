import type { D1Client, D1PreparedStatementLike, D1Queryable } from '@stanmieszkania/d1';
import {
  SystemUuidV7Generator,
  createJsonLogger,
  systemClock,
  type Clock,
  type IdGenerator,
  type Logger,
} from '@stanmieszkania/shared';
import type { AppConfig } from '../config/app-config';
import type {
  ApartmentCommandGateway,
  ApartmentCoordinatorNamespaceLike,
} from '../durable-objects/apartment-coordinator.types';
import type { UserGuardNamespaceLike } from '../durable-objects/user-guard.types';
import {
  createD1AccountDeletionRepository,
  createDeleteMyAccountUseCase,
  type AccountDeletionRepository,
  type AppleTokenRevokerPort,
  type IdentityProviderDeleterPort,
  type MediaCleanupPort,
} from '../modules/account-deletion';
import { createD1ApartmentRepository, type ApartmentRepository } from '../modules/apartments';
import { createD1EntryRepository, type EntryRepository } from '../modules/entries';
import {
  createAuthenticateUserUseCase,
  createD1UserRepository,
  createUpdateDisplayNameUseCase,
  type TokenVerifierPort,
  type UserRepository,
} from '../modules/identity';
import {
  createD1MediaRepository,
  type LocalR2BucketLike,
  type MediaRepository,
  type ObjectStoragePort,
} from '../modules/media';
import {
  createD1MembershipRepository,
  type InviteCodeRateLimiterPort,
  type MembershipRepository,
} from '../modules/membership';
import { createD1SyncRepository, type SyncRepository } from '../modules/sync';
import { buildModuleRouteHandlers } from './build-route-handlers';
import type { RequestContainer } from './hono-variables';
import { resolveRuntimeAdapters } from './resolve-adapters';
import { createSerializedAccountDeletionRepository } from './serialized-account-deletion';

export interface RequestContainerOverrides {
  readonly clock?: Clock;
  readonly idGenerator?: IdGenerator;
  readonly logger?: Logger;
  readonly userRepository?: UserRepository;
  readonly apartmentRepository?: ApartmentRepository;
  readonly membershipRepository?: MembershipRepository;
  readonly mediaRepository?: MediaRepository;
  readonly entryRepository?: EntryRepository;
  readonly syncRepository?: SyncRepository;
  readonly accountDeletionRepository?: AccountDeletionRepository;
  readonly inviteRateLimiter?: InviteCodeRateLimiterPort;
  readonly apartmentGateway?: ApartmentCommandGateway;
  readonly objectStorage?: ObjectStoragePort;
  readonly mediaCleanup?: MediaCleanupPort;
  readonly appleTokenRevoker?: AppleTokenRevokerPort;
  readonly identityProviderDeleter?: IdentityProviderDeleterPort;
  readonly tokenVerifier?: TokenVerifierPort;
}

export interface CreateRequestContainerInput<
  TStatement extends D1PreparedStatementLike<TStatement>,
> {
  readonly db: D1Client<TStatement> & D1Queryable;
  readonly mediaBucket?: LocalR2BucketLike;
  readonly userGuard?: UserGuardNamespaceLike;
  readonly apartmentCoordinator?: ApartmentCoordinatorNamespaceLike;
  readonly appConfig: AppConfig;
  readonly requestId: string;
  readonly overrides?: RequestContainerOverrides;
}

export function createRequestContainer<TStatement extends D1PreparedStatementLike<TStatement>>(
  input: CreateRequestContainerInput<TStatement>,
): RequestContainer {
  const clock = input.overrides?.clock ?? systemClock;
  const idGenerator = input.overrides?.idGenerator ?? new SystemUuidV7Generator();
  const baseLogger = input.overrides?.logger ?? createJsonLogger({ clock });
  const logger = baseLogger.child({ requestId: input.requestId });

  const userRepository = input.overrides?.userRepository ?? createD1UserRepository(input.db);
  const apartmentRepository =
    input.overrides?.apartmentRepository ?? createD1ApartmentRepository(input.db);
  const membershipRepository =
    input.overrides?.membershipRepository ?? createD1MembershipRepository(input.db);
  const mediaRepository = input.overrides?.mediaRepository ?? createD1MediaRepository(input.db);
  const entryRepository = input.overrides?.entryRepository ?? createD1EntryRepository(input.db);
  const syncRepository = input.overrides?.syncRepository ?? createD1SyncRepository(input.db);
  const rawAccountDeletionRepository =
    input.overrides?.accountDeletionRepository ?? createD1AccountDeletionRepository(input.db);

  const adapters = resolveRuntimeAdapters({
    appConfig: input.appConfig,
    clock,
    mediaBucket: input.mediaBucket,
    userGuard: input.userGuard,
    apartmentCoordinator: input.apartmentCoordinator,
    overrides: input.overrides,
  });

  const accountDeletionRepository = createSerializedAccountDeletionRepository(
    rawAccountDeletionRepository,
    adapters.apartmentGateway,
  );

  const authenticateUser = createAuthenticateUserUseCase({
    tokenVerifier: adapters.tokenVerifier,
    userRepository,
    idGenerator,
    clock,
  });
  const updateDisplayName = createUpdateDisplayNameUseCase({ userRepository });
  const deleteMyAccount = createDeleteMyAccountUseCase({
    accountDeletionRepository,
    mediaCleanup: adapters.mediaCleanup,
    appleTokenRevoker: adapters.appleTokenRevoker,
    identityProviderDeleter: adapters.identityProviderDeleter,
    clock,
    logger,
  });

  const handlers = buildModuleRouteHandlers({
    appConfig: input.appConfig,
    clock,
    idGenerator,
    apartmentRepository,
    membershipRepository,
    mediaRepository,
    entryRepository,
    syncRepository,
    inviteRateLimiter: adapters.inviteRateLimiter,
    apartmentGateway: adapters.apartmentGateway,
    objectStorage: adapters.objectStorage,
    mediaCleanup: adapters.mediaCleanup,
    mediaBucket: input.mediaBucket,
  });

  return {
    clock,
    idGenerator,
    appConfig: input.appConfig,
    logger,
    userRepository,
    apartmentRepository,
    membershipRepository,
    mediaRepository,
    entryRepository,
    syncRepository,
    accountDeletionRepository,
    ...adapters,
    authenticateUser,
    updateDisplayName,
    deleteMyAccount,
    ...handlers,
  };
}
