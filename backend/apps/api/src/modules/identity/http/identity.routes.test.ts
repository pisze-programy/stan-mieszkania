import {
  HEADER_NAMES,
  HTTP_STATUS,
  PROBLEM_JSON_CONTENT_TYPE,
  ProblemDetailsSchema,
} from '@stanmieszkania/http-contracts';
import { FixedClock, RecordingLogger, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../../../app';
import { createD1TestHarness, type D1TestHarness } from '../../../testing/d1-test-harness';
import { DEFAULT_USER_NAME_PREFIX } from '../domain/identity.constants';
import { UserProfileSchema } from './identity.schema';

describe('Identity HTTP routes (/v1/me)', () => {
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

  it('creates user on first GET /v1/me (with/without SIwA name) and is idempotent on repeat login', async () => {
    const logger = new RecordingLogger();
    const app = createApp({
      overrides: {
        clock: new FixedClock(),
        idGenerator: new SequentialUuidV7Generator(),
        logger,
      },
    });
    const env = { DB: getHarness().db, AUTH_MODE: 'local' };

    const firstAnon = await app.request(
      '/v1/me',
      { headers: { Authorization: 'Bearer dev:uid-anon', [HEADER_NAMES.REQUEST_ID]: 'req-1' } },
      env,
    );
    expect(firstAnon.status).toBe(HTTP_STATUS.OK);
    const anonProfile = UserProfileSchema.parse(await firstAnon.json());
    expect(anonProfile.displayName).toBe(`${DEFAULT_USER_NAME_PREFIX}${anonProfile.shortTag}`);

    const repeatAnon = await app.request(
      '/v1/me',
      { headers: { Authorization: 'Bearer dev:uid-anon' } },
      env,
    );
    expect(repeatAnon.status).toBe(HTTP_STATUS.OK);
    expect(UserProfileSchema.parse(await repeatAnon.json())).toEqual(anonProfile);

    const firstNamed = await app.request(
      '/v1/me',
      { headers: { Authorization: 'Bearer dev:uid-named:Maria%20K' } },
      env,
    );
    expect(firstNamed.status).toBe(HTTP_STATUS.OK);
    const namedProfile = UserProfileSchema.parse(await firstNamed.json());
    expect(namedProfile.displayName).toBe('Maria K');
  });

  it('updates profile via PATCH /v1/me and returns problem+json on invalid inputs', async () => {
    const app = createApp({
      overrides: {
        clock: new FixedClock(),
        idGenerator: new SequentialUuidV7Generator({ startCounter: 100 }),
      },
    });
    const env = { DB: getHarness().db, AUTH_MODE: 'local' };

    const patchOk = await app.request(
      '/v1/me',
      {
        method: 'PATCH',
        headers: {
          Authorization: 'Bearer dev:uid-patch',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ displayName: '  Nowe Imię  ' }),
      },
      env,
    );
    expect(patchOk.status).toBe(HTTP_STATUS.OK);
    expect(UserProfileSchema.parse(await patchOk.json()).displayName).toBe('Nowe Imię');

    const patchWhitespace = await app.request(
      '/v1/me',
      {
        method: 'PATCH',
        headers: {
          Authorization: 'Bearer dev:uid-patch',
          'Content-Type': 'application/json',
          [HEADER_NAMES.REQUEST_ID]: 'req-whitespace',
        },
        body: JSON.stringify({ displayName: '   ' }),
      },
      env,
    );
    expect(patchWhitespace.status).toBe(HTTP_STATUS.UNPROCESSABLE_ENTITY);
    expect(patchWhitespace.headers.get('Content-Type')).toContain(PROBLEM_JSON_CONTENT_TYPE);
    expect(ProblemDetailsSchema.parse(await patchWhitespace.json())).toMatchObject({
      code: 'DISPLAY_NAME_INVALID',
      requestId: 'req-whitespace',
    });

    const patchEmpty = await app.request(
      '/v1/me',
      {
        method: 'PATCH',
        headers: {
          Authorization: 'Bearer dev:uid-patch',
          'Content-Type': 'application/json',
          [HEADER_NAMES.REQUEST_ID]: 'req-empty',
        },
        body: JSON.stringify({ displayName: '' }),
      },
      env,
    );
    expect(patchEmpty.status).toBe(HTTP_STATUS.BAD_REQUEST);
    expect(ProblemDetailsSchema.parse(await patchEmpty.json())).toMatchObject({
      code: 'VALIDATION_ERROR',
      requestId: 'req-empty',
    });
  });

  it('returns 401 for missing/invalid/firebase-mode tokens and 403 for deleted accounts', async () => {
    const app = createApp();
    const db = getHarness().db;
    const env = { DB: db, AUTH_MODE: 'local' };

    const missing = await app.request('/v1/me', {}, env);
    expect(missing.status).toBe(HTTP_STATUS.UNAUTHORIZED);
    expect(ProblemDetailsSchema.parse(await missing.json()).code).toBe('AUTH_TOKEN_MISSING');

    const invalid = await app.request(
      '/v1/me',
      { headers: { Authorization: 'Bearer not-dev-token' } },
      env,
    );
    expect(invalid.status).toBe(HTTP_STATUS.UNAUTHORIZED);
    expect(ProblemDetailsSchema.parse(await invalid.json()).code).toBe('AUTH_TOKEN_INVALID');

    const firebaseFailClosed = await app.request(
      '/v1/me',
      { headers: { Authorization: 'Bearer dev:uid-anon' } },
      { DB: db, AUTH_MODE: 'firebase' },
    );
    expect(firebaseFailClosed.status).toBe(HTTP_STATUS.UNAUTHORIZED);

    await db
      .prepare(
        'INSERT INTO users (id, firebase_uid, display_name, short_tag, color, created_at, deleted_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      )
      .bind(
        '01933e2a-7b40-7000-8000-000000000999',
        'uid-deleted',
        'Usunięty użytkownik',
        'ABCD',
        '#007AFF',
        '2026-11-18T12:00:00.000Z',
        '2026-11-18T13:00:00.000Z',
      )
      .run();

    const deletedRes = await app.request(
      '/v1/me',
      { headers: { Authorization: 'Bearer dev:uid-deleted' } },
      env,
    );
    expect(deletedRes.status).toBe(HTTP_STATUS.FORBIDDEN);
    expect(ProblemDetailsSchema.parse(await deletedRes.json()).code).toBe('USER_DELETED');
  });
});
