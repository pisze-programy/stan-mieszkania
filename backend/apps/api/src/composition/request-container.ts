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
import {
  createUserGuardInviteRateLimiter,
  createUserGuardMediaCleanup,
} from '../durable-objects/user-guard.client';
import type {
  UserGuardNamespaceLike,
  UserGuardR2BucketLike,
} from '../durable-objects/user-guard.types';
import {
  createD1AccountDeletionRepository,
  createDeleteMyAccountUseCase,
  createDirectR2MediaCleanup,
  createFailClosedAppleTokenRevoker,
  createFailClosedIdentityProviderDeleter,
  createLocalAppleTokenRevoker,
  createLocalIdentityProviderDeleter,
  type AccountDeletionRepository,
  type AppleTokenRevokerPort,
  type IdentityProviderDeleterPort,
  type MediaCleanupPort,
} from '../modules/account-deletion';
import {
  createCreateApartmentUseCase,
  createD1ApartmentRepository,
  createDeleteOrLeaveApartmentUseCase,
  createGetApartmentUseCase,
  createListApartmentChangesUseCase,
  createListMyApartmentsUseCase,
  createResetInviteCodeUseCase,
  createUpdateApartmentUseCase,
  type ApartmentRepository,
} from '../modules/apartments';
import {
  createAuthenticateUserUseCase,
  createD1UserRepository,
  createFailClosedTokenVerifier,
  createLocalDevTokenVerifier,
  createUpdateDisplayNameUseCase,
  type TokenVerifierPort,
  type UserRepository,
} from '../modules/identity';
import {
  createAllowAllInviteRateLimiter,
  createD1MembershipRepository,
  createJoinApartmentByCodeUseCase,
  createLeaveApartmentUseCase,
  createListApartmentMembersUseCase,
  createRevokeMemberAccessUseCase,
  type InviteCodeRateLimiterPort,
  type MembershipRepository,
} from '../modules/membership';
import type { RequestContainer } from './hono-variables';

export interface RequestContainerOverrides {
  readonly clock?: Clock;
  readonly idGenerator?: IdGenerator;
  readonly logger?: Logger;
  readonly userRepository?: UserRepository;
  readonly apartmentRepository?: ApartmentRepository;
  readonly membershipRepository?: MembershipRepository;
  readonly accountDeletionRepository?: AccountDeletionRepository;
  readonly inviteRateLimiter?: InviteCodeRateLimiterPort;
  readonly mediaCleanup?: MediaCleanupPort;
  readonly appleTokenRevoker?: AppleTokenRevokerPort;
  readonly identityProviderDeleter?: IdentityProviderDeleterPort;
  readonly tokenVerifier?: TokenVerifierPort;
}

export interface CreateRequestContainerInput<
  TStatement extends D1PreparedStatementLike<TStatement>,
> {
  readonly db: D1Client<TStatement> & D1Queryable;
  readonly mediaBucket?: UserGuardR2BucketLike;
  readonly userGuard?: UserGuardNamespaceLike;
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
  const accountDeletionRepository =
    input.overrides?.accountDeletionRepository ?? createD1AccountDeletionRepository(input.db);

  const inviteRateLimiter =
    input.overrides?.inviteRateLimiter ??
    (input.userGuard !== undefined
      ? createUserGuardInviteRateLimiter({
          namespace: input.userGuard,
          maxAttempts: input.appConfig.inviteCodeRateLimitMaxAttempts,
          windowMs: input.appConfig.inviteCodeRateLimitWindowMs,
          clock,
        })
      : createAllowAllInviteRateLimiter());

  const mediaCleanup =
    input.overrides?.mediaCleanup ??
    (input.userGuard !== undefined
      ? createUserGuardMediaCleanup({ namespace: input.userGuard, clock })
      : createDirectR2MediaCleanup(input.mediaBucket));

  const appleTokenRevoker =
    input.overrides?.appleTokenRevoker ??
    (input.appConfig.authMode === 'local'
      ? createLocalAppleTokenRevoker()
      : createFailClosedAppleTokenRevoker());

  const identityProviderDeleter =
    input.overrides?.identityProviderDeleter ??
    (input.appConfig.authMode === 'local'
      ? createLocalIdentityProviderDeleter()
      : createFailClosedIdentityProviderDeleter());

  const tokenVerifier =
    input.overrides?.tokenVerifier ??
    (input.appConfig.authMode === 'local'
      ? createLocalDevTokenVerifier()
      : createFailClosedTokenVerifier());

  const authenticateUser = createAuthenticateUserUseCase({
    tokenVerifier,
    userRepository,
    idGenerator,
    clock,
  });
  const updateDisplayName = createUpdateDisplayNameUseCase({ userRepository });
  const deleteMyAccount = createDeleteMyAccountUseCase({
    accountDeletionRepository,
    mediaCleanup,
    appleTokenRevoker,
    identityProviderDeleter,
    clock,
    logger,
  });

  const apartments = {
    createApartment: createCreateApartmentUseCase({ apartmentRepository, clock }),
    listMyApartments: createListMyApartmentsUseCase({ apartmentRepository }),
    getApartment: createGetApartmentUseCase({ apartmentRepository }),
    updateApartment: createUpdateApartmentUseCase({ apartmentRepository, clock, idGenerator }),
    resetInviteCode: createResetInviteCodeUseCase({ apartmentRepository, clock }),
    deleteOrLeaveApartment: createDeleteOrLeaveApartmentUseCase({ apartmentRepository, clock }),
    listApartmentChanges: createListApartmentChangesUseCase({ apartmentRepository }),
  };
  const membership = {
    joinApartment: createJoinApartmentByCodeUseCase({
      membershipRepository,
      inviteRateLimiter,
      clock,
    }),
    listMembers: createListApartmentMembersUseCase({ membershipRepository }),
    revokeMember: createRevokeMemberAccessUseCase({ membershipRepository, clock }),
    leaveApartment: createLeaveApartmentUseCase({ membershipRepository, clock }),
  };

  return {
    clock,
    idGenerator,
    appConfig: input.appConfig,
    logger,
    userRepository,
    apartmentRepository,
    membershipRepository,
    accountDeletionRepository,
    inviteRateLimiter,
    mediaCleanup,
    appleTokenRevoker,
    identityProviderDeleter,
    tokenVerifier,
    authenticateUser,
    updateDisplayName,
    deleteMyAccount,
    apartments,
    membership,
  };
}
