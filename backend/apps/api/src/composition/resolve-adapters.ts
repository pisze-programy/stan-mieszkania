import type { Clock } from '@stanmieszkania/shared';
import type { AppConfig } from '../config/app-config';
import {
  createDurableObjectApartmentCommandGateway,
  createInProcessApartmentCommandGateway,
} from '../durable-objects/apartment-coordinator.gateway';
import type {
  ApartmentCommandGateway,
  ApartmentCoordinatorNamespaceLike,
} from '../durable-objects/apartment-coordinator.types';
import {
  createUserGuardInviteRateLimiter,
  createUserGuardMediaCleanup,
} from '../durable-objects/user-guard.client';
import type { UserGuardNamespaceLike } from '../durable-objects/user-guard.types';
import {
  createAppleAuthRevoker,
  createDirectR2MediaCleanup,
  createFailClosedAppleTokenRevoker,
  createFailClosedIdentityProviderDeleter,
  createFirebaseIdentityDeleter,
  createLocalAppleTokenRevoker,
  createLocalIdentityProviderDeleter,
  type AppleTokenRevokerPort,
  type IdentityProviderDeleterPort,
  type MediaCleanupPort,
} from '../modules/account-deletion';
import {
  createFailClosedTokenVerifier,
  createFirebaseJwksTokenVerifier,
  createLocalDevTokenVerifier,
  type TokenVerifierPort,
} from '../modules/identity';
import {
  createFailClosedObjectStorage,
  createLocalR2ObjectStorage,
  type LocalR2BucketLike,
  type ObjectStoragePort,
} from '../modules/media';
import {
  createAllowAllInviteRateLimiter,
  type InviteCodeRateLimiterPort,
} from '../modules/membership';

export interface ResolveAdaptersInput {
  readonly appConfig: AppConfig;
  readonly clock: Clock;
  readonly mediaBucket: LocalR2BucketLike | undefined;
  readonly userGuard: UserGuardNamespaceLike | undefined;
  readonly apartmentCoordinator: ApartmentCoordinatorNamespaceLike | undefined;
  readonly overrides:
    | {
        readonly inviteRateLimiter?: InviteCodeRateLimiterPort;
        readonly apartmentGateway?: ApartmentCommandGateway;
        readonly objectStorage?: ObjectStoragePort;
        readonly mediaCleanup?: MediaCleanupPort;
        readonly appleTokenRevoker?: AppleTokenRevokerPort;
        readonly identityProviderDeleter?: IdentityProviderDeleterPort;
        readonly tokenVerifier?: TokenVerifierPort;
      }
    | undefined;
}

export interface ResolvedAdapters {
  readonly inviteRateLimiter: InviteCodeRateLimiterPort;
  readonly apartmentGateway: ApartmentCommandGateway;
  readonly objectStorage: ObjectStoragePort;
  readonly mediaCleanup: MediaCleanupPort;
  readonly appleTokenRevoker: AppleTokenRevokerPort;
  readonly identityProviderDeleter: IdentityProviderDeleterPort;
  readonly tokenVerifier: TokenVerifierPort;
}

function resolveProductionAppleRevoker(appConfig: AppConfig, clock: Clock): AppleTokenRevokerPort {
  if (
    appConfig.appleTeamId !== undefined &&
    appConfig.appleClientId !== undefined &&
    appConfig.appleKeyId !== undefined &&
    appConfig.applePrivateKeyPem !== undefined
  ) {
    return createAppleAuthRevoker({
      teamId: appConfig.appleTeamId,
      clientId: appConfig.appleClientId,
      keyId: appConfig.appleKeyId,
      privateKeyPem: appConfig.applePrivateKeyPem,
      clock,
    });
  }
  return createFailClosedAppleTokenRevoker();
}

function resolveProductionFirebaseDeleter(
  appConfig: AppConfig,
  clock: Clock,
): IdentityProviderDeleterPort {
  if (
    appConfig.firebaseClientEmail !== undefined &&
    appConfig.firebasePrivateKeyPem !== undefined
  ) {
    return createFirebaseIdentityDeleter({
      clientEmail: appConfig.firebaseClientEmail,
      privateKeyPem: appConfig.firebasePrivateKeyPem,
      ...(appConfig.firebaseProjectId !== undefined
        ? { projectId: appConfig.firebaseProjectId }
        : {}),
      clock,
    });
  }
  return createFailClosedIdentityProviderDeleter();
}

function resolveProductionTokenVerifier(appConfig: AppConfig, clock: Clock): TokenVerifierPort {
  if (appConfig.firebaseProjectId !== undefined) {
    return createFirebaseJwksTokenVerifier({
      firebaseProjectId: appConfig.firebaseProjectId,
      clock,
    });
  }
  return createFailClosedTokenVerifier();
}

export function resolveRuntimeAdapters(input: ResolveAdaptersInput): ResolvedAdapters {
  const { appConfig, clock, mediaBucket, userGuard, apartmentCoordinator, overrides } = input;

  const objectStorage =
    overrides?.objectStorage ??
    (appConfig.storageMode === 'local'
      ? createLocalR2ObjectStorage({ bucket: mediaBucket, clock })
      : createFailClosedObjectStorage());

  const inviteRateLimiter =
    overrides?.inviteRateLimiter ??
    (userGuard !== undefined
      ? createUserGuardInviteRateLimiter({
          namespace: userGuard,
          maxAttempts: appConfig.inviteCodeRateLimitMaxAttempts,
          windowMs: appConfig.inviteCodeRateLimitWindowMs,
          clock,
        })
      : createAllowAllInviteRateLimiter());

  const apartmentGateway =
    overrides?.apartmentGateway ??
    (apartmentCoordinator !== undefined
      ? createDurableObjectApartmentCommandGateway(apartmentCoordinator)
      : createInProcessApartmentCommandGateway());

  const mediaCleanup =
    overrides?.mediaCleanup ??
    (userGuard !== undefined
      ? createUserGuardMediaCleanup({ namespace: userGuard, clock })
      : createDirectR2MediaCleanup(mediaBucket));

  const appleTokenRevoker =
    overrides?.appleTokenRevoker ??
    (appConfig.authMode === 'local'
      ? createLocalAppleTokenRevoker()
      : resolveProductionAppleRevoker(appConfig, clock));

  const identityProviderDeleter =
    overrides?.identityProviderDeleter ??
    (appConfig.authMode === 'local'
      ? createLocalIdentityProviderDeleter()
      : resolveProductionFirebaseDeleter(appConfig, clock));

  const tokenVerifier =
    overrides?.tokenVerifier ??
    (appConfig.authMode === 'local'
      ? createLocalDevTokenVerifier()
      : resolveProductionTokenVerifier(appConfig, clock));

  return {
    inviteRateLimiter,
    apartmentGateway,
    objectStorage,
    mediaCleanup,
    appleTokenRevoker,
    identityProviderDeleter,
    tokenVerifier,
  };
}
