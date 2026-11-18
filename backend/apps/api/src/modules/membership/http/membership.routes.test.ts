import { HTTP_STATUS, ProblemDetailsSchema } from '@stanmieszkania/http-contracts';
import { FixedClock, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../../../app';
import { createD1TestHarness, type D1TestHarness } from '../../../testing/d1-test-harness';
import { ApartmentDtoSchema } from '../../apartments';
import { InMemoryInviteRateLimiter } from '../testing/in-memory-invite-rate-limiter';
import { ApartmentMemberListResponseSchema } from './membership.schema';

const jsonHeaders = (token: string) => ({
  Authorization: `Bearer ${token}`,
  'Content-Type': 'application/json',
});

describe('Membership HTTP routes (/v1/apartments/*)', () => {
  let harness: D1TestHarness | undefined;
  const ids = new SequentialUuidV7Generator();

  const getHarness = (): D1TestHarness => {
    if (harness === undefined) {
      throw new Error('D1 test harness was not initialized');
    }
    return harness;
  };

  beforeAll(async () => {
    harness = await createD1TestHarness();
  });

  afterAll(async () => {
    await harness?.dispose();
  });

  it('supports join by invite code, invite-reset prompt & invalidation, member listing, and revocation', async () => {
    const clock = new FixedClock();
    const app = createApp({
      overrides: { clock, idGenerator: ids },
    });
    const env = { DB: getHarness().db, AUTH_MODE: 'local' };
    const aptId = '01933e2a-7b40-7000-8000-000000000020';

    const putRes = await app.request(
      `/v1/apartments/${aptId}`,
      {
        method: 'PUT',
        headers: jsonHeaders('dev:owner-fb:Jan'),
        body: JSON.stringify({ name: 'M1', street: 'S1', city: 'Warszawa' }),
      },
      env,
    );
    expect(putRes.status).toBe(HTTP_STATUS.OK);
    const created = ApartmentDtoSchema.parse(await putRes.json());
    const originalCode = created.inviteCode ?? '';

    clock.advanceBy(1_000);
    const joinRes = await app.request(
      '/v1/apartments/join',
      {
        method: 'POST',
        headers: jsonHeaders('dev:contrib-fb:Anna'),
        body: JSON.stringify({ inviteCode: originalCode.toLowerCase().replace('-', ' ') }),
      },
      env,
    );
    expect(joinRes.status).toBe(HTTP_STATUS.OK);
    const joined = ApartmentDtoSchema.parse(await joinRes.json());
    expect(joined.role).toBe('contributor');
    expect(joined.inviteCode).toBeNull();
    expect(joined.shouldSuggestInviteCodeReset).toBe(false);

    const ownerGet = await app.request(
      `/v1/apartments/${aptId}`,
      { headers: { Authorization: 'Bearer dev:owner-fb' } },
      env,
    );
    expect(ApartmentDtoSchema.parse(await ownerGet.json()).shouldSuggestInviteCodeReset).toBe(true);

    const membersRes = await app.request(
      `/v1/apartments/${aptId}/members`,
      { headers: { Authorization: 'Bearer dev:contrib-fb' } },
      env,
    );
    expect(membersRes.status).toBe(HTTP_STATUS.OK);
    const members = ApartmentMemberListResponseSchema.parse(await membersRes.json()).items;
    expect(members).toHaveLength(2);
    const contribMember = members.find((m) => m.role === 'contributor');
    const ownerMember = members.find((m) => m.role === 'owner');
    expect(contribMember?.displayName).toBe('Anna');
    expect(ownerMember?.displayName).toBe('Jan');

    clock.advanceBy(1_000);
    const resetRes = await app.request(
      `/v1/apartments/${aptId}/invite-code/reset`,
      { method: 'POST', headers: { Authorization: 'Bearer dev:owner-fb' } },
      env,
    );
    expect(resetRes.status).toBe(HTTP_STATUS.OK);
    expect(ApartmentDtoSchema.parse(await resetRes.json()).shouldSuggestInviteCodeReset).toBe(
      false,
    );

    const oldCodeJoin = await app.request(
      '/v1/apartments/join',
      {
        method: 'POST',
        headers: jsonHeaders('dev:other-fb:Piotr'),
        body: JSON.stringify({ inviteCode: originalCode }),
      },
      env,
    );
    expect(oldCodeJoin.status).toBe(HTTP_STATUS.NOT_FOUND);
    expect(ProblemDetailsSchema.parse(await oldCodeJoin.json()).code).toBe('INVITE_CODE_NOT_FOUND');

    const ownerSelfRevoke = await app.request(
      `/v1/apartments/${aptId}/members/${ownerMember?.userId ?? ''}`,
      { method: 'DELETE', headers: { Authorization: 'Bearer dev:owner-fb' } },
      env,
    );
    expect(ownerSelfRevoke.status).toBe(HTTP_STATUS.CONFLICT);
    expect(ProblemDetailsSchema.parse(await ownerSelfRevoke.json()).code).toBe(
      'CANNOT_REVOKE_OWNER',
    );

    const revokeRes = await app.request(
      `/v1/apartments/${aptId}/members/${contribMember?.userId ?? ''}`,
      { method: 'DELETE', headers: { Authorization: 'Bearer dev:owner-fb' } },
      env,
    );
    expect(revokeRes.status).toBe(HTTP_STATUS.NO_CONTENT);

    const contribAfterRevoke = await app.request(
      `/v1/apartments/${aptId}`,
      { headers: { Authorization: 'Bearer dev:contrib-fb' } },
      env,
    );
    expect(contribAfterRevoke.status).toBe(HTTP_STATUS.FORBIDDEN);
  });

  it('supports contributor leave, owner leave conflict, invalid invite code 422, and rate limit 429', async () => {
    const app = createApp({
      overrides: {
        clock: new FixedClock(),
        idGenerator: ids,
        inviteRateLimiter: new InMemoryInviteRateLimiter({ maxAttempts: 2 }),
      },
    });
    const env = { DB: getHarness().db, AUTH_MODE: 'local' };
    const aptId = '01933e2a-7b40-7000-8000-000000000021';

    const putRes = await app.request(
      `/v1/apartments/${aptId}`,
      {
        method: 'PUT',
        headers: jsonHeaders('dev:owner2-fb:Marek'),
        body: JSON.stringify({ name: 'M2', street: 'S2', city: 'Kraków' }),
      },
      env,
    );
    const created = ApartmentDtoSchema.parse(await putRes.json());

    const joinRes = await app.request(
      '/v1/apartments/join',
      {
        method: 'POST',
        headers: jsonHeaders('dev:contrib2-fb:Ewa'),
        body: JSON.stringify({ inviteCode: created.inviteCode }),
      },
      env,
    );
    expect(joinRes.status).toBe(HTTP_STATUS.OK);

    const leaveRes = await app.request(
      `/v1/apartments/${aptId}/leave`,
      { method: 'POST', headers: { Authorization: 'Bearer dev:contrib2-fb' } },
      env,
    );
    expect(leaveRes.status).toBe(HTTP_STATUS.NO_CONTENT);

    const ownerLeaveRes = await app.request(
      `/v1/apartments/${aptId}/leave`,
      { method: 'POST', headers: { Authorization: 'Bearer dev:owner2-fb' } },
      env,
    );
    expect(ownerLeaveRes.status).toBe(HTTP_STATUS.CONFLICT);

    const invalidRes = await app.request(
      '/v1/apartments/join',
      {
        method: 'POST',
        headers: jsonHeaders('dev:contrib2-fb'),
        body: JSON.stringify({ inviteCode: 'ABCD-01IO' }),
      },
      env,
    );
    expect(invalidRes.status).toBe(HTTP_STATUS.UNPROCESSABLE_ENTITY);

    const limitedRes = await app.request(
      '/v1/apartments/join',
      {
        method: 'POST',
        headers: jsonHeaders('dev:contrib2-fb'),
        body: JSON.stringify({ inviteCode: created.inviteCode }),
      },
      env,
    );
    expect(limitedRes.status).toBe(HTTP_STATUS.TOO_MANY_REQUESTS);
    expect(ProblemDetailsSchema.parse(await limitedRes.json()).code).toBe(
      'INVITE_CODE_RATE_LIMITED',
    );
  });
});
