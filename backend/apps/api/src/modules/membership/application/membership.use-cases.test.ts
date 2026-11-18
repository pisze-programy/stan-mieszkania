import { isErr, isOk } from '@stanmieszkania/shared';
import { FixedClock } from '@stanmieszkania/testing';
import { describe, expect, it } from 'vitest';
import { createJoinApartmentByCodeUseCase } from './join-apartment-by-code.use-case';
import { createLeaveApartmentUseCase } from './leave-apartment.use-case';
import { createListApartmentMembersUseCase } from './list-apartment-members.use-case';
import { createRevokeMemberAccessUseCase } from './revoke-member-access.use-case';
import { MEMBERSHIP_ERROR_CODES } from '../domain/membership.errors';
import { InMemoryInviteRateLimiter } from '../testing/in-memory-invite-rate-limiter';
import { InMemoryMembershipRepository } from '../testing/in-memory-membership.repository';

function setupRepo() {
  const repo = new InMemoryMembershipRepository();
  const clock = new FixedClock();
  repo.seedUser({ id: 'usr-owner', displayName: 'Jan', shortTag: 'JAN1', color: '#007AFF' });
  repo.seedUser({ id: 'usr-contrib', displayName: 'Anna', shortTag: 'ANN2', color: '#34C759' });
  repo.seedApartment({
    id: 'apt-1',
    ownerId: 'usr-owner',
    name: 'M1',
    street: 'S1',
    city: 'Warszawa',
    inviteCode: 'K7QM-4XPB',
    inviteCodeRotatedAt: null,
    cloudMediaCount: 0,
    createdAt: clock.nowIso(),
    updatedAt: clock.nowIso(),
  });
  return { repo, clock };
}

describe('membership use cases', () => {
  it('enforces rate limit, normalizes invite code, joins idempotently, and reactivates former contributor', async () => {
    const { repo, clock } = setupRepo();
    const join = createJoinApartmentByCodeUseCase({
      membershipRepository: repo,
      inviteRateLimiter: new InMemoryInviteRateLimiter({ maxAttempts: 5 }),
      clock,
    });

    const invalid = await join.execute({ userId: 'usr-contrib', inviteCode: 'K7QM-0XPB' });
    expect(isErr(invalid) && invalid.error.code).toBe(MEMBERSHIP_ERROR_CODES.INVITE_CODE_INVALID);

    const notFound = await join.execute({ userId: 'usr-contrib', inviteCode: 'AAAA-BBBB' });
    expect(isErr(notFound) && notFound.error.code).toBe(
      MEMBERSHIP_ERROR_CODES.INVITE_CODE_NOT_FOUND,
    );

    const joined = await join.execute({ userId: 'usr-contrib', inviteCode: ' k7qm 4xpb ' });
    expect(isOk(joined)).toBe(true);
    if (isOk(joined)) {
      expect(joined.value.role).toBe('contributor');
      expect(joined.value.apartment.id).toBe('apt-1');
    }

    const replay = await join.execute({ userId: 'usr-contrib', inviteCode: 'K7QM-4XPB' });
    expect(isOk(replay)).toBe(true);
    expect(repo.changeLog).toHaveLength(1);

    const limitedJoin = createJoinApartmentByCodeUseCase({
      membershipRepository: repo,
      inviteRateLimiter: new InMemoryInviteRateLimiter({ maxAttempts: 0 }),
      clock,
    });
    const rateLimited = await limitedJoin.execute({
      userId: 'usr-contrib',
      inviteCode: 'K7QM-4XPB',
    });
    expect(isErr(rateLimited) && rateLimited.error.code).toBe(
      MEMBERSHIP_ERROR_CODES.INVITE_CODE_RATE_LIMITED,
    );
  });

  it('lists enriched members, revokes contributors, and handles leave rules', async () => {
    const { repo, clock } = setupRepo();
    const join = createJoinApartmentByCodeUseCase({
      membershipRepository: repo,
      inviteRateLimiter: new InMemoryInviteRateLimiter({ maxAttempts: 10 }),
      clock,
    });
    const listMembers = createListApartmentMembersUseCase({ membershipRepository: repo });
    const revoke = createRevokeMemberAccessUseCase({ membershipRepository: repo, clock });
    const leave = createLeaveApartmentUseCase({ membershipRepository: repo, clock });

    const deniedBeforeJoin = await listMembers.execute({
      apartmentId: 'apt-1',
      userId: 'usr-contrib',
    });
    expect(isErr(deniedBeforeJoin) && deniedBeforeJoin.error.code).toBe(
      MEMBERSHIP_ERROR_CODES.MEMBERSHIP_ACCESS_DENIED,
    );

    await join.execute({ userId: 'usr-contrib', inviteCode: 'K7QM-4XPB' });
    const members = await listMembers.execute({ apartmentId: 'apt-1', userId: 'usr-contrib' });
    expect(isOk(members) && members.value).toHaveLength(2);

    const contribRevoke = await revoke.execute({
      apartmentId: 'apt-1',
      actorUserId: 'usr-contrib',
      targetUserId: 'usr-owner',
    });
    expect(isErr(contribRevoke) && contribRevoke.error.code).toBe(
      MEMBERSHIP_ERROR_CODES.MEMBERSHIP_OWNER_REQUIRED,
    );

    const ownerSelfRevoke = await revoke.execute({
      apartmentId: 'apt-1',
      actorUserId: 'usr-owner',
      targetUserId: 'usr-owner',
    });
    expect(isErr(ownerSelfRevoke) && ownerSelfRevoke.error.code).toBe(
      MEMBERSHIP_ERROR_CODES.CANNOT_REVOKE_OWNER,
    );

    const ownerLeave = await leave.execute({ apartmentId: 'apt-1', userId: 'usr-owner' });
    expect(isErr(ownerLeave) && ownerLeave.error.code).toBe(
      MEMBERSHIP_ERROR_CODES.CANNOT_REVOKE_OWNER,
    );

    clock.advanceBy(10_000);
    expect(
      (
        await revoke.execute({
          apartmentId: 'apt-1',
          actorUserId: 'usr-owner',
          targetUserId: 'usr-contrib',
        })
      ).ok,
    ).toBe(true);

    clock.advanceBy(10_000);
    expect((await join.execute({ userId: 'usr-contrib', inviteCode: 'K7QM-4XPB' })).ok).toBe(true);
    clock.advanceBy(10_000);
    expect((await leave.execute({ apartmentId: 'apt-1', userId: 'usr-contrib' })).ok).toBe(true);
    expect(repo.changeLog.map((item) => item.op)).toEqual(['joined', 'revoked', 'joined', 'left']);
  });
});
