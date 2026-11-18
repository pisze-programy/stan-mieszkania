import { days, isErr, isOk } from '@stanmieszkania/shared';
import { FixedClock, RecordingLogger } from '@stanmieszkania/testing';
import { describe, expect, it } from 'vitest';
import { ORPHAN_APARTMENT_RETENTION_DAYS } from '../../apartments';
import { DELETED_USER_DISPLAY_NAME } from '../../identity';
import { ACCOUNT_DELETION_ERROR_CODES } from '../domain/account-deletion.errors';
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
    const logger = new RecordingLogger();
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
      logger,
    });

    const result = await useCase.execute({
      userId: 'user-1',
      firebaseUid: 'fb-uid-1',
      appleAuthorizationCode: '  apple-auth-code-xyz  ',
    });

    const expectedDeletedAt = clock.nowIso();
    const expectedOrphanAt = new Date(
      clock.nowMs() + days(ORPHAN_APARTMENT_RETENTION_DAYS),
    ).toISOString();

    expect(isOk(result)).toBe(true);
    if (isOk(result)) {
      expect(result.value).toEqual({
        deletedAt: expectedDeletedAt,
        hardDeletedApartmentIds: ['apt-private'],
        transferredApartmentIds: ['apt-shared-transfer'],
        orphanScheduledApartmentIds: ['apt-shared-orphan'],
        leftAsContributorApartmentIds: ['apt-contrib-active'],
        deletedR2Keys: ['apt-private/m1.jpg', 'apt-private/m2.jpg'],
      });
    }

    expect(repo.hardDeletedApartmentIds).toEqual(['apt-private']);
    expect(repo.transfers).toEqual([
      {
        apartmentId: 'apt-shared-transfer',
        previousOwnerId: 'user-1',
        newOwnerId: 'user-early-a',
        leftAt: expectedDeletedAt,
      },
    ]);
    expect(repo.orphanSchedules).toEqual([
      {
        apartmentId: 'apt-shared-orphan',
        ownerId: 'user-1',
        orphanDeleteAfter: expectedOrphanAt,
        leftAt: expectedDeletedAt,
      },
    ]);
    expect(repo.contributorDepartures).toEqual([
      {
        apartmentId: 'apt-contrib-active',
        userId: 'user-1',
        leftAt: expectedDeletedAt,
      },
    ]);
    expect(repo.anonymizedUsers).toEqual([
      {
        userId: 'user-1',
        displayName: DELETED_USER_DISPLAY_NAME,
        deletedAt: expectedDeletedAt,
      },
    ]);
    expect(mediaCleanup.batches).toEqual([
      { userId: 'user-1', r2Keys: ['apt-private/m1.jpg', 'apt-private/m2.jpg'] },
    ]);
    expect(appleRevoker.revokedCodes).toEqual(['apple-auth-code-xyz']);
    expect(providerDeleter.deletedFirebaseUids).toEqual(['fb-uid-1']);
  });

  it('rejects blank appleAuthorizationCode before mutating state', async () => {
    const repo = new InMemoryAccountDeletionRepository();
    const useCase = createDeleteMyAccountUseCase({
      accountDeletionRepository: repo,
      mediaCleanup: new RecordingMediaCleanup(),
      appleTokenRevoker: new RecordingAppleTokenRevoker(),
      identityProviderDeleter: new RecordingIdentityProviderDeleter(),
      clock: new FixedClock(),
      logger: new RecordingLogger(),
    });

    const result = await useCase.execute({
      userId: 'user-1',
      firebaseUid: 'fb-uid-1',
      appleAuthorizationCode: '   ',
    });

    expect(isErr(result)).toBe(true);
    if (isErr(result)) {
      expect(result.error.code).toBe(ACCOUNT_DELETION_ERROR_CODES.INVALID_APPLE_AUTHORIZATION_CODE);
    }
    expect(repo.anonymizedUsers).toEqual([]);
  });
});
