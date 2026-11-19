import { HTTP_STATUS, ProblemDetailsSchema } from '@stanmieszkania/http-contracts';
import { err, ok } from '@stanmieszkania/shared';
import { FixedClock, RecordingLogger, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../../../app';
import { COMMON_ERROR_CODES } from '../../../http/http.constants';
import { createD1TestHarness, type D1TestHarness } from '../../../testing/d1-test-harness';
import { IDENTITY_ERROR_CODES } from '../../identity';
import {
  ACCOUNT_DELETION_ERROR_CODES,
  externalAuthCleanupFailedError,
} from '../domain/account-deletion.errors';

describe('DELETE /v1/me retryability and empty body (Miniflare D1 + R2 + UserGuard DO)', () => {
  let harness: D1TestHarness | undefined;
  const idGenerator = new SequentialUuidV7Generator();
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

  it('leaves account intact and retryable after 502 external auth failure, and accepts empty body', async () => {
    let failDelete = true;
    const app = createApp({
      overrides: {
        clock: new FixedClock('2026-11-18T13:00:00.000Z'),
        idGenerator,
        logger: new RecordingLogger(),
        identityProviderDeleter: {
          deleteProviderUser: () =>
            Promise.resolve(
              failDelete ? err(externalAuthCleanupFailedError('Firebase timeout')) : ok(),
            ),
        },
      },
    });
    const env = {
      DB: getHarness().db,
      MEDIA_BUCKET: getHarness().r2,
      USER_GUARD: getHarness().userGuard,
      AUTH_MODE: 'local',
    };
    const headers = { Authorization: 'Bearer dev:retry-empty-user:Marek' };

    expect((await app.request('/v1/me', { headers }, env)).status).toBe(HTTP_STATUS.OK);

    const failedRes = await app.request('/v1/me', { method: 'DELETE', headers }, env);
    expect(failedRes.status).toBe(HTTP_STATUS.BAD_GATEWAY);
    const problem = ProblemDetailsSchema.parse(await failedRes.json());
    expect(problem.code).toBe(COMMON_ERROR_CODES.INTERNAL_ERROR);
    expect(problem.detail).not.toContain('Firebase timeout');
    expect((await app.request('/v1/me', { headers }, env)).status).toBe(HTTP_STATUS.OK);

    failDelete = false;
    expect((await app.request('/v1/me', { method: 'DELETE', headers }, env)).status).toBe(
      HTTP_STATUS.NO_CONTENT,
    );

    const blockedRes = await app.request('/v1/me', { headers }, env);
    expect(blockedRes.status).toBe(HTTP_STATUS.FORBIDDEN);
    expect(ProblemDetailsSchema.parse(await blockedRes.json()).code).toBe(
      IDENTITY_ERROR_CODES.USER_DELETED,
    );
  });

  it('rejects omitted appleAuthorizationCode with 422 in firebase auth mode before touching providers or D1', async () => {
    let deleterCalled = false;
    const app = createApp({
      overrides: {
        clock: new FixedClock('2026-11-18T14:00:00.000Z'),
        idGenerator,
        logger: new RecordingLogger(),
        tokenVerifier: {
          verifyIdToken: () =>
            Promise.resolve(ok({ firebaseUid: 'fb-prod-user-1', displayName: 'Kasia' })),
        },
        identityProviderDeleter: {
          deleteProviderUser: () => {
            deleterCalled = true;
            return Promise.resolve(ok());
          },
        },
      },
    });
    const env = {
      DB: getHarness().db,
      MEDIA_BUCKET: getHarness().r2,
      USER_GUARD: getHarness().userGuard,
      AUTH_MODE: 'firebase',
      FIREBASE_PROJECT_ID: 'demo-stanmieszkania',
    };
    const headers = { Authorization: 'Bearer fake-firebase-jwt' };

    expect((await app.request('/v1/me', { headers }, env)).status).toBe(HTTP_STATUS.OK);

    const rejected = await app.request('/v1/me', { method: 'DELETE', headers }, env);
    expect(rejected.status).toBe(HTTP_STATUS.UNPROCESSABLE_ENTITY);
    expect(ProblemDetailsSchema.parse(await rejected.json()).code).toBe(
      ACCOUNT_DELETION_ERROR_CODES.INVALID_APPLE_AUTHORIZATION_CODE,
    );
    expect(deleterCalled).toBe(false);
    expect((await app.request('/v1/me', { headers }, env)).status).toBe(HTTP_STATUS.OK);
  });
});
