import { HTTP_STATUS, ProblemDetailsSchema } from '@stanmieszkania/http-contracts';
import { FixedClock, RecordingLogger, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../app';
import { MEMBERSHIP_ERROR_CODES } from '../modules/membership';
import { createD1TestHarness, type D1TestHarness } from '../testing/d1-test-harness';

describe('UserGuard DO invite-code rate limiting over HTTP (Miniflare D1 + DO)', () => {
  let harness: D1TestHarness | undefined;

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

  it('returns 429 INVITE_CODE_RATE_LIMITED after max attempts and recovers after window expiry', async () => {
    const clock = new FixedClock('2026-11-18T10:00:00.000Z');
    const app = createApp({
      overrides: {
        clock,
        idGenerator: new SequentialUuidV7Generator(),
        logger: new RecordingLogger(),
      },
    });
    const env = {
      DB: getHarness().db,
      MEDIA_BUCKET: getHarness().r2,
      USER_GUARD: getHarness().userGuard,
      AUTH_MODE: 'local',
      INVITE_CODE_RATE_LIMIT_MAX_ATTEMPTS: '2',
      INVITE_CODE_RATE_LIMIT_WINDOW_SECONDS: '60',
    };
    const headers = {
      Authorization: 'Bearer dev:rate-limited-user:Jan',
      'content-type': 'application/json',
    };
    const body = JSON.stringify({ inviteCode: 'XXXX-YYYY' });

    const first = await app.request('/v1/apartments/join', { method: 'POST', headers, body }, env);
    expect(first.status).toBe(HTTP_STATUS.NOT_FOUND);

    const second = await app.request('/v1/apartments/join', { method: 'POST', headers, body }, env);
    expect(second.status).toBe(HTTP_STATUS.NOT_FOUND);

    const limited = await app.request(
      '/v1/apartments/join',
      { method: 'POST', headers, body },
      env,
    );
    expect(limited.status).toBe(HTTP_STATUS.TOO_MANY_REQUESTS);
    const problem = ProblemDetailsSchema.parse(await limited.json());
    expect(problem.code).toBe(MEMBERSHIP_ERROR_CODES.INVITE_CODE_RATE_LIMITED);
    expect(problem.details?.['retryAfterSeconds']).toBe(60);

    clock.advanceBy(61_000);
    const recovered = await app.request(
      '/v1/apartments/join',
      { method: 'POST', headers, body },
      env,
    );
    expect(recovered.status).toBe(HTTP_STATUS.NOT_FOUND);
  });
});
