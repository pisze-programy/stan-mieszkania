import { days, err, isErr, isOk, ok } from '@stanmieszkania/shared';
import { FixedClock, RecordingLogger } from '@stanmieszkania/testing';
import { describe, expect, it } from 'vitest';
import { ORPHAN_APARTMENT_RETENTION_DAYS } from '../../apartments';
import { DELETED_USER_DISPLAY_NAME } from '../../identity';
import {
  ACCOUNT_DELETION_ERROR_CODES,
  externalAuthCleanupFailedError,
} from '../domain/account-deletion.errors';
import {
  InMemoryAccountDeletionRepository,
  RecordingAppleTokenRevoker,
  RecordingIdentityProviderDeleter,
  RecordingMediaCleanup,
} from '../testing/in-memory-account-deletion.doubles';
import { createDeleteMyAccountUseCase } from './delete-my-account.use-case';

describe('createDeleteMyAccountUseCase', () => {
  it('handles private hard-delete, shared transfer, orphan scheduling, contributor leave, and external cleanup', async () => {
    const clock = new FixedClock('2026-11-18T12:00:00.000Z');
    const repo = new InMemoryAccountDeletionRepository({
      'user-1': [
        {
          apartmentId: 'apt-private',
          role: 'owner',
          isActiveMembership: true,
          activeContributors: [],
          hasSharedHistory: false,
          mediaR2Keys: ['apt-private/m1.jpg', 'apt-private/m2.jpg'],
        },
        {
          apartmentId: 'apt-shared-transfer',
          role: 'owner',
          isActiveMembership: true,
          activeContributors: [
            { userId: 'user-late', joinedAt: '2026-11-10T10:00:00.000Z' },
            { userId: 'user-early-b', joinedAt: '2026-11-05T10:00:00.000Z' },
            { userId: 'user-early-a', joinedAt: '2026-11-05T10:00:00.000Z' },
          ],
          hasSharedHistory: true,
          mediaR2Keys: ['apt-shared-transfer/m3.jpg'],
        },
        {
          apartmentId: 'apt-shared-orphan',
          role: 'owner',
          isActiveMembership: true,
          activeContributors: [],
          hasSharedHistory: true,
          mediaR2Keys: ['apt-shared-orphan/m4.jpg'],
        },
        {
          apartmentId: 'apt-contrib-active',
          role: 'contributor',
          isActiveMembership: true,
          activeContributors: [],
          hasSharedHistory: true,
          mediaR2Keys: ['apt-contrib-active/m5.jpg'],
        },
        {
          apartmentId: 'apt-contrib-already-left',
          role: 'contributor',
          isActiveMembership: false,
          activeContributors: [],
          hasSharedHistory: true,
          mediaR2Keys: [],
        },
      ],
    });
    const mediaCleanup = new RecordingMediaCleanup();
    const appleRevoker = new RecordingAppleTokenRevoker();
    const providerDeleter = new RecordingIdentityProviderDeleter();
    const useCase = createDeleteMyAccountUseCase({
      accountDeletionRepository: repo,
      mediaCleanup,
      appleTokenRevoker: appleRevoker,
      identityProviderDeleter: providerDeleter,
      clock,
      logger: new RecordingLogger(),
    });

    const result = await useCase.execute({
      userId: 'user-1',
      firebaseUid: 'fb-uid-1',
      appleAuthorizationCode: '  apple-auth-code-xyz  ',
    });

    const deletedAt = clock.nowIso();
    const orphanDeleteAfter = new Date(
      clock.nowMs() + days(ORPHAN_APARTMENT_RETENTION_DAYS),
    ).toISOString();

    expect(result).toEqual(
      ok({
        deletedAt,
        hardDeletedApartmentIds: ['apt-private'],
        transferredApartmentIds: ['apt-shared-transfer'],
        orphanScheduledApartmentIds: ['apt-shared-orphan'],
        leftAsContributorApartmentIds: ['apt-contrib-active'],
        deletedR2Keys: ['apt-private/m1.jpg', 'apt-private/m2.jpg'],
      }),
    );
    expect(repo.hardDeletedApartmentIds).toEqual(['apt-private']);
    expect(repo.transfers).toEqual([
      {
        apartmentId: 'apt-shared-transfer',
        previousOwnerId: 'user-1',
        newOwnerId: 'user-early-a',
        leftAt: deletedAt,
      },
    ]);
    expect(repo.orphanSchedules).toEqual([
      { apartmentId: 'apt-shared-orphan', ownerId: 'user-1', orphanDeleteAfter, leftAt: deletedAt },
    ]);
    expect(repo.contributorDepartures).toEqual([
      { apartmentId: 'apt-contrib-active', userId: 'user-1', leftAt: deletedAt },
    ]);
    expect(repo.anonymizedUsers).toEqual([
      { userId: 'user-1', displayName: DELETED_USER_DISPLAY_NAME, deletedAt },
    ]);
    expect(mediaCleanup.batches).toEqual([
      { userId: 'user-1', r2Keys: ['apt-private/m1.jpg', 'apt-private/m2.jpg'] },
    ]);
    expect(appleRevoker.revokedCodes).toEqual(['apple-auth-code-xyz']);
    expect(providerDeleter.deletedFirebaseUids).toEqual(['fb-uid-1']);
  });

  it('aborts before destructive D1/R2 writes when external auth cleanup fails and allows retry', async () => {
    const repo = new InMemoryAccountDeletionRepository({
      'user-1': [
        {
          apartmentId: 'apt-private',
          role: 'owner',
          isActiveMembership: true,
          activeContributors: [],
          hasSharedHistory: false,
          mediaR2Keys: ['apt-private/m1.jpg'],
        },
      ],
    });
    const mediaCleanup = new RecordingMediaCleanup();
    let failExternal = true;
    const useCase = createDeleteMyAccountUseCase({
      accountDeletionRepository: repo,
      mediaCleanup,
      appleTokenRevoker: {
        revokeAuthorizationCode: () =>
          Promise.resolve(
            failExternal ? err(externalAuthCleanupFailedError('Apple outage')) : ok(),
          ),
      },
      identityProviderDeleter: new RecordingIdentityProviderDeleter(),
      clock: new FixedClock(),
      logger: new RecordingLogger(),
    });

    const cmd = { userId: 'user-1', firebaseUid: 'fb-uid-1', appleAuthorizationCode: 'code-1' };
    const failed = await useCase.execute(cmd);
    expect(isErr(failed)).toBe(true);
    if (isErr(failed)) {
      expect(failed.error.code).toBe(ACCOUNT_DELETION_ERROR_CODES.EXTERNAL_AUTH_CLEANUP_FAILED);
    }
    expect(repo.hardDeletedApartmentIds).toEqual([]);
    expect(repo.anonymizedUsers).toEqual([]);
    expect(mediaCleanup.batches).toEqual([]);

    failExternal = false;
    expect(isOk(await useCase.execute(cmd))).toBe(true);
    expect(repo.hardDeletedApartmentIds).toEqual(['apt-private']);
    expect(repo.anonymizedUsers).toHaveLength(1);
    expect(mediaCleanup.batches).toHaveLength(1);
  });

  it('rejects blank or required omitted appleAuthorizationCode before mutating state', async () => {
    const repo = new InMemoryAccountDeletionRepository();
    const providerDeleter = new RecordingIdentityProviderDeleter();
    const useCase = createDeleteMyAccountUseCase({
      accountDeletionRepository: repo,
      mediaCleanup: new RecordingMediaCleanup(),
      appleTokenRevoker: new RecordingAppleTokenRevoker(),
      identityProviderDeleter: providerDeleter,
      clock: new FixedClock(),
      logger: new RecordingLogger(),
      requireAppleAuthorizationCode: true,
    });

    for (const appleAuthorizationCode of ['   ', undefined]) {
      const result = await useCase.execute({
        userId: 'user-1',
        firebaseUid: 'fb-uid-1',
        ...(appleAuthorizationCode !== undefined ? { appleAuthorizationCode } : {}),
      });
      expect(isErr(result)).toBe(true);
      if (isErr(result)) {
        expect(result.error.code).toBe(
          ACCOUNT_DELETION_ERROR_CODES.INVALID_APPLE_AUTHORIZATION_CODE,
        );
      }
    }
    expect(providerDeleter.deletedFirebaseUids).toEqual([]);
    expect(repo.anonymizedUsers).toEqual([]);
  });
});
