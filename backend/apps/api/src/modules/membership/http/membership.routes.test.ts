import { HTTP_STATUS, ProblemDetailsSchema } from '@stanmieszkania/http-contracts';
import { FixedClock, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../../../app';
import { createD1TestHarness, type D1TestHarness } from '../../../testing/d1-test-harness';
import { ApartmentDtoSchema } from '../../apartments';
import { InMemoryInviteRateLimiter } from '../testing/in-memory-invite-rate-limiter';
import { ApartmentMemberListResponseSchema } from './membership.schema';

type App = ReturnType<typeof createApp>;

const req = (
  app: App,
  path: string,
  token: string,
  env: Record<string, unknown>,
  method = 'GET',
  body?: unknown,
) =>
  app.request(
    path,
    {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
      },
      ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
    },
    env,
  );

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

  it('supports join, invite-reset prompt & invalidation, member listing, revocation block, and post-reset rejoin', async () => {
    const clock = new FixedClock();
    const app = createApp({ overrides: { clock, idGenerator: ids } });
    const env = { DB: getHarness().db, AUTH_MODE: 'local' };
    const aptId = '01933e2a-7b40-7000-8000-000000000020';

    const putRes = await req(app, `/v1/apartments/${aptId}`, 'dev:owner-fb:Jan', env, 'PUT', {
      name: 'M1',
      street: 'S1',
      city: 'Warszawa',
    });
    expect(putRes.status).toBe(HTTP_STATUS.OK);
    const created = ApartmentDtoSchema.parse(await putRes.json());
    const originalCode = created.inviteCode ?? '';

    clock.advanceBy(1_000);
    const joinRes = await req(app, '/v1/apartments/join', 'dev:contrib-fb:Anna', env, 'POST', {
      inviteCode: originalCode.toLowerCase().replace('-', ' '),
    });
    expect(joinRes.status).toBe(HTTP_STATUS.OK);
    const joined = ApartmentDtoSchema.parse(await joinRes.json());
    expect(joined).toMatchObject({
      role: 'contributor',
      inviteCode: null,
      shouldSuggestInviteCodeReset: false,
    });

    const ownerGet = await req(app, `/v1/apartments/${aptId}`, 'dev:owner-fb', env);
    expect(ApartmentDtoSchema.parse(await ownerGet.json()).shouldSuggestInviteCodeReset).toBe(true);

    const membersRes = await req(app, `/v1/apartments/${aptId}/members`, 'dev:contrib-fb', env);
    expect(membersRes.status).toBe(HTTP_STATUS.OK);
    const members = ApartmentMemberListResponseSchema.parse(await membersRes.json()).items;
    expect(members).toHaveLength(2);
    const contribMember = members.find((m) => m.role === 'contributor');
    const ownerMember = members.find((m) => m.role === 'owner');

    clock.advanceBy(1_000);
    const resetRes = await req(
      app,
      `/v1/apartments/${aptId}/invite-code/reset`,
      'dev:owner-fb',
      env,
      'POST',
    );
    const rotated = ApartmentDtoSchema.parse(await resetRes.json());
    expect(rotated.shouldSuggestInviteCodeReset).toBe(false);

    const oldCodeJoin = await req(app, '/v1/apartments/join', 'dev:other-fb:Piotr', env, 'POST', {
      inviteCode: originalCode,
    });
    expect(oldCodeJoin.status).toBe(HTTP_STATUS.NOT_FOUND);
    expect(ProblemDetailsSchema.parse(await oldCodeJoin.json()).code).toBe('INVITE_CODE_NOT_FOUND');

    const ownerSelfRevoke = await req(
      app,
      `/v1/apartments/${aptId}/members/${ownerMember?.userId ?? ''}`,
      'dev:owner-fb',
      env,
      'DELETE',
    );
    expect(ownerSelfRevoke.status).toBe(HTTP_STATUS.CONFLICT);
    expect(ProblemDetailsSchema.parse(await ownerSelfRevoke.json()).code).toBe(
      'CANNOT_REVOKE_OWNER',
    );

    clock.advanceBy(1_000);
    const revokeRes = await req(
      app,
      `/v1/apartments/${aptId}/members/${contribMember?.userId ?? ''}`,
      'dev:owner-fb',
      env,
      'DELETE',
    );
    expect(revokeRes.status).toBe(HTTP_STATUS.NO_CONTENT);
    expect((await req(app, `/v1/apartments/${aptId}`, 'dev:contrib-fb', env)).status).toBe(
      HTTP_STATUS.FORBIDDEN,
    );

    const blockedRejoin = await req(app, '/v1/apartments/join', 'dev:contrib-fb', env, 'POST', {
      inviteCode: rotated.inviteCode,
    });
    expect(blockedRejoin.status).toBe(HTTP_STATUS.FORBIDDEN);
    expect(ProblemDetailsSchema.parse(await blockedRejoin.json()).code).toBe(
      'MEMBERSHIP_ACCESS_DENIED',
    );

    clock.advanceBy(1_000);
    const secondReset = ApartmentDtoSchema.parse(
      await (
        await req(app, `/v1/apartments/${aptId}/invite-code/reset`, 'dev:owner-fb', env, 'POST')
      ).json(),
    );
    const allowedRejoin = await req(app, '/v1/apartments/join', 'dev:contrib-fb', env, 'POST', {
      inviteCode: secondReset.inviteCode,
    });
    expect(allowedRejoin.status).toBe(HTTP_STATUS.OK);
  });

  it('supports leave, owner leave conflict, invalid code 422, rate limit 429, and blocks orphan join', async () => {
    const app = createApp({
      overrides: {
        clock: new FixedClock(),
        idGenerator: ids,
        inviteRateLimiter: new InMemoryInviteRateLimiter({ maxAttempts: 2 }),
      },
    });
    const env = { DB: getHarness().db, AUTH_MODE: 'local' };
    const aptId = '01933e2a-7b40-7000-8000-000000000021';

    const putRes = await req(app, `/v1/apartments/${aptId}`, 'dev:owner2-fb:Marek', env, 'PUT', {
      name: 'M2',
      street: 'S2',
      city: 'Kraków',
    });
    const created = ApartmentDtoSchema.parse(await putRes.json());

    expect(
      (
        await req(app, '/v1/apartments/join', 'dev:contrib2-fb:Ewa', env, 'POST', {
          inviteCode: created.inviteCode,
        })
      ).status,
    ).toBe(HTTP_STATUS.OK);
    expect(
      (await req(app, `/v1/apartments/${aptId}/leave`, 'dev:contrib2-fb', env, 'POST')).status,
    ).toBe(HTTP_STATUS.NO_CONTENT);
    expect(
      (await req(app, `/v1/apartments/${aptId}/leave`, 'dev:owner2-fb', env, 'POST')).status,
    ).toBe(HTTP_STATUS.CONFLICT);
    expect(
      (
        await req(app, '/v1/apartments/join', 'dev:contrib2-fb', env, 'POST', {
          inviteCode: 'ABCD-01IO',
        })
      ).status,
    ).toBe(HTTP_STATUS.UNPROCESSABLE_ENTITY);

    const limitedRes = await req(app, '/v1/apartments/join', 'dev:contrib2-fb', env, 'POST', {
      inviteCode: created.inviteCode,
    });
    expect(limitedRes.status).toBe(HTTP_STATUS.TOO_MANY_REQUESTS);
    expect(ProblemDetailsSchema.parse(await limitedRes.json()).code).toBe(
      'INVITE_CODE_RATE_LIMITED',
    );

    await getHarness()
      .db.prepare('UPDATE apartments SET orphan_delete_after = ? WHERE id = ?')
      .bind('2026-12-18T12:00:00.000Z', aptId)
      .run();
    expect(
      (
        await req(app, '/v1/apartments/join', 'dev:stranger2-fb:Ola', env, 'POST', {
          inviteCode: created.inviteCode,
        })
      ).status,
    ).toBe(HTTP_STATUS.NOT_FOUND);
  });
});
