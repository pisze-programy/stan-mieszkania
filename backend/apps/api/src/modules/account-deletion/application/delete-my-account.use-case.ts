import {
  err,
  ok,
  type Clock,
  type DomainError,
  type Logger,
  type Result,
} from '@stanmieszkania/shared';
import { resolveOwnerDeparture } from '../../apartments';
import { DELETED_USER_DISPLAY_NAME } from '../../identity';
import {
  APPLE_AUTH_CODE_MAX_LENGTH,
  APPLE_AUTH_CODE_MIN_LENGTH,
} from '../domain/account-deletion.constants';
import { invalidAppleAuthorizationCodeError } from '../domain/account-deletion.errors';
import type { AccountDeletionRepository } from '../domain/account-deletion.repository';
import type {
  AppleTokenRevokerPort,
  IdentityProviderDeleterPort,
  MediaCleanupPort,
} from '../domain/external-auth-cleanup.port';

export interface DeleteMyAccountCommand {
  readonly userId: string;
  readonly firebaseUid: string | null;
  readonly appleAuthorizationCode?: string;
}

export interface DeleteMyAccountOutcome {
  readonly deletedAt: string;
  readonly hardDeletedApartmentIds: readonly string[];
  readonly transferredApartmentIds: readonly string[];
  readonly orphanScheduledApartmentIds: readonly string[];
  readonly leftAsContributorApartmentIds: readonly string[];
  readonly deletedR2Keys: readonly string[];
}

export interface DeleteMyAccountDeps {
  readonly accountDeletionRepository: AccountDeletionRepository;
  readonly mediaCleanup: MediaCleanupPort;
  readonly appleTokenRevoker: AppleTokenRevokerPort;
  readonly identityProviderDeleter: IdentityProviderDeleterPort;
  readonly clock: Clock;
  readonly logger: Logger;
}

export interface DeleteMyAccountUseCase {
  execute(command: DeleteMyAccountCommand): Promise<Result<DeleteMyAccountOutcome, DomainError>>;
}

function normalizeAppleAuthCode(
  rawCode: string | undefined,
): Result<string | undefined, DomainError> {
  if (rawCode === undefined) {
    return ok(undefined);
  }
  const trimmed = rawCode.trim();
  if (trimmed.length < APPLE_AUTH_CODE_MIN_LENGTH || trimmed.length > APPLE_AUTH_CODE_MAX_LENGTH) {
    return err(
      invalidAppleAuthorizationCodeError('Apple authorization code length is out of bounds'),
    );
  }
  return ok(trimmed);
}

// Decision Q5 & Q12: Revoke external auth first so 502 failures stay retryable before destructive D1/R2 purge.
export function createDeleteMyAccountUseCase(deps: DeleteMyAccountDeps): DeleteMyAccountUseCase {
  return {
    execute: async (command) => {
      const normalizedCode = normalizeAppleAuthCode(command.appleAuthorizationCode);
      if (!normalizedCode.ok) {
        return normalizedCode;
      }

      if (normalizedCode.value !== undefined) {
        const revoked = await deps.appleTokenRevoker.revokeAuthorizationCode(normalizedCode.value);
        if (!revoked.ok) {
          deps.logger.error('Apple token revocation failed during account deletion', {
            userId: command.userId,
            errorCode: revoked.error.code,
          });
          return revoked;
        }
      }

      if (command.firebaseUid !== null) {
        const providerDeleted = await deps.identityProviderDeleter.deleteProviderUser(
          command.firebaseUid,
        );
        if (!providerDeleted.ok) {
          deps.logger.error('Identity provider deletion failed during account deletion', {
            userId: command.userId,
            errorCode: providerDeleted.error.code,
          });
          return providerDeleted;
        }
      }

      const nowMs = deps.clock.nowMs();
      const nowIso = deps.clock.nowIso();

      const apartmentsResult = await deps.accountDeletionRepository.listUserApartments(
        command.userId,
      );
      if (!apartmentsResult.ok) {
        return apartmentsResult;
      }

      const hardDeletedApartmentIds: string[] = [];
      const transferredApartmentIds: string[] = [];
      const orphanScheduledApartmentIds: string[] = [];
      const leftAsContributorApartmentIds: string[] = [];
      const r2KeysToDelete: string[] = [];

      for (const apartment of apartmentsResult.value) {
        if (!apartment.isActiveMembership) {
          continue;
        }

        if (apartment.role === 'owner') {
          const resolution = resolveOwnerDeparture({
            activeContributors: apartment.activeContributors,
            hasSharedHistory: apartment.hasSharedHistory,
            trigger: 'account_deletion',
            nowMs,
          });

          if (resolution.action === 'hard_delete') {
            const deleted = await deps.accountDeletionRepository.hardDeletePrivateApartment(
              apartment.apartmentId,
            );
            if (!deleted.ok) {
              return deleted;
            }
            hardDeletedApartmentIds.push(apartment.apartmentId);
            r2KeysToDelete.push(...apartment.mediaR2Keys);
          } else if (resolution.action === 'transfer') {
            const transferred = await deps.accountDeletionRepository.transferOwnershipAndLeave({
              apartmentId: apartment.apartmentId,
              previousOwnerId: command.userId,
              newOwnerId: resolution.newOwnerId,
              leftAt: nowIso,
            });
            if (!transferred.ok) {
              return transferred;
            }
            transferredApartmentIds.push(apartment.apartmentId);
          } else {
            const scheduled = await deps.accountDeletionRepository.scheduleOrphanDeleteAndLeave({
              apartmentId: apartment.apartmentId,
              ownerId: command.userId,
              orphanDeleteAfter: resolution.orphanDeleteAfter,
              leftAt: nowIso,
            });
            if (!scheduled.ok) {
              return scheduled;
            }
            orphanScheduledApartmentIds.push(apartment.apartmentId);
          }
          continue;
        }

        const left = await deps.accountDeletionRepository.leaveAsContributor({
          apartmentId: apartment.apartmentId,
          userId: command.userId,
          leftAt: nowIso,
        });
        if (!left.ok) {
          return left;
        }
        leftAsContributorApartmentIds.push(apartment.apartmentId);
      }

      // Decision Q5: Keep firebase_uid on anonymized row so cached 15-min JWTs fail immediately with 403 USER_DELETED.
      const anonymized = await deps.accountDeletionRepository.anonymizeUserPreservingUid(
        command.userId,
        DELETED_USER_DISPLAY_NAME,
        nowIso,
      );
      if (!anonymized.ok) {
        return anonymized;
      }

      if (r2KeysToDelete.length > 0) {
        const cleanupResult = await deps.mediaCleanup.deletePrivateMediaObjects(
          command.userId,
          r2KeysToDelete,
        );
        if (!cleanupResult.ok) {
          deps.logger.error('Failed to enqueue private media cleanup during account deletion', {
            userId: command.userId,
            keyCount: r2KeysToDelete.length,
            errorCode: cleanupResult.error.code,
          });
          return cleanupResult;
        }
      }

      return ok({
        deletedAt: nowIso,
        hardDeletedApartmentIds,
        transferredApartmentIds,
        orphanScheduledApartmentIds,
        leftAsContributorApartmentIds,
        deletedR2Keys: r2KeysToDelete,
      });
    },
  };
}
