import { HTTP_STATUS, ProblemDetailsSchema } from '@stanmieszkania/http-contracts';
import { FixedClock, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../../../app';
import { createD1TestHarness, type D1TestHarness } from '../../../testing/d1-test-harness';
import {
  ApartmentDtoSchema,
  ApartmentHistoryResponseSchema,
  ApartmentListResponseSchema,
} from './apartments.schema';

describe('Apartments HTTP routes (/v1/apartments)', () => {
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

  it('supports idempotent PUT, GET list/detail, PATCH + history, invite-code reset, and solo DELETE', async () => {
    const app = createApp({
      overrides: { clock: new FixedClock(), idGenerator: new SequentialUuidV7Generator() },
    });
    const env = { DB: getHarness().db, MEDIA_BUCKET: getHarness().r2, AUTH_MODE: 'local' };
    const aptId = '01933e2a-7b40-7000-8000-000000000010';
    const ownerHeaders = {
      Authorization: 'Bearer dev:owner-fb:Jan',
      'Content-Type': 'application/json',
    };

    const putRes = await app.request(
      `/v1/apartments/${aptId}`,
      {
        method: 'PUT',
        headers: ownerHeaders,
        body: JSON.stringify({ name: 'M1', street: 'S1', city: 'Warszawa' }),
      },
      env,
    );
    expect(putRes.status).toBe(HTTP_STATUS.OK);
    const created = ApartmentDtoSchema.parse(await putRes.json());
    expect(created.role).toBe('owner');
    expect(created.inviteCode).toMatch(/^[2-9A-HJ-NP-Z]{4}-[2-9A-HJ-NP-Z]{4}$/);

    const replayRes = await app.request(
      `/v1/apartments/${aptId}`,
      {
        method: 'PUT',
        headers: ownerHeaders,
        body: JSON.stringify({ name: 'Ignored', street: 'S1', city: 'Warszawa' }),
      },
      env,
    );
    expect(ApartmentDtoSchema.parse(await replayRes.json())).toEqual(created);

    const listRes = await app.request(
      '/v1/apartments',
      { headers: { Authorization: 'Bearer dev:owner-fb' } },
      env,
    );
    expect(ApartmentListResponseSchema.parse(await listRes.json()).items).toHaveLength(1);

    const patchRes = await app.request(
      `/v1/apartments/${aptId}`,
      { method: 'PATCH', headers: ownerHeaders, body: JSON.stringify({ name: 'M1 Updated' }) },
      env,
    );
    expect(ApartmentDtoSchema.parse(await patchRes.json()).name).toBe('M1 Updated');

    const historyRes = await app.request(
      `/v1/apartments/${aptId}/history`,
      { headers: { Authorization: 'Bearer dev:owner-fb' } },
      env,
    );
    const history = ApartmentHistoryResponseSchema.parse(await historyRes.json());
    expect(history.items).toHaveLength(1);
    expect(history.items[0]).toMatchObject({
      field: 'name',
      oldValue: 'M1',
      newValue: 'M1 Updated',
    });

    const resetRes = await app.request(
      `/v1/apartments/${aptId}/invite-code/reset`,
      { method: 'POST', headers: { Authorization: 'Bearer dev:owner-fb' } },
      env,
    );
    const rotated = ApartmentDtoSchema.parse(await resetRes.json());
    expect(rotated.inviteCode).not.toBeNull();
    expect(rotated.inviteCode).not.toBe(created.inviteCode);

    const r2Key = `apartments/${aptId}/solo-photo.jpg`;
    await getHarness().r2.put(r2Key, 'jpeg-bytes');
    await getHarness()
      .db.prepare(
        'INSERT INTO media (id, apartment_id, author_id, kind, source, upload_status, sha256, captured_at, captured_tz, width, height, bytes, r2_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      )
      .bind(
        'med-solo-1',
        aptId,
        created.ownerId,
        'photo',
        'camera',
        'confirmed',
        'abc',
        created.createdAt,
        'Europe/Warsaw',
        100,
        100,
        10,
        r2Key,
      )
      .run();

    const deleteRes = await app.request(
      `/v1/apartments/${aptId}`,
      { method: 'DELETE', headers: { Authorization: 'Bearer dev:owner-fb' } },
      env,
    );
    expect(deleteRes.status).toBe(HTTP_STATUS.NO_CONTENT);
    expect(await getHarness().r2.get(r2Key)).toBeNull();

    const afterDeleteGet = await app.request(
      `/v1/apartments/${aptId}`,
      { headers: { Authorization: 'Bearer dev:owner-fb' } },
      env,
    );
    expect(afterDeleteGet.status).toBe(HTTP_STATUS.NOT_FOUND);
  });

  it('hides inviteCode from contributors and rejects non-members / non-owners with 403', async () => {
    const app = createApp({
      overrides: {
        clock: new FixedClock(),
        idGenerator: new SequentialUuidV7Generator({ startCounter: 50 }),
      },
    });
    const db = getHarness().db;
    const env = { DB: db, AUTH_MODE: 'local' };
    const aptId = '01933e2a-7b40-7000-8000-000000000020';

    await app.request(
      `/v1/apartments/${aptId}`,
      {
        method: 'PUT',
        headers: { Authorization: 'Bearer dev:owner-2', 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: 'Shared', street: 'Ulica 2', city: 'Gdańsk' }),
      },
      env,
    );

    const strangerGet = await app.request(
      `/v1/apartments/${aptId}`,
      { headers: { Authorization: 'Bearer dev:stranger-fb' } },
      env,
    );
    expect(strangerGet.status).toBe(HTTP_STATUS.FORBIDDEN);
    expect(ProblemDetailsSchema.parse(await strangerGet.json()).code).toBe(
      'APARTMENT_ACCESS_DENIED',
    );

    const contribMe = await app.request(
      '/v1/me',
      { headers: { Authorization: 'Bearer dev:contrib-fb' } },
      env,
    );
    const contribUser = (await contribMe.json()) as { id: string }; // reason: parsing test user id from /v1/me response
    await db
      .prepare(
        'INSERT INTO memberships (apartment_id, user_id, role, joined_at) VALUES (?, ?, ?, ?)',
      )
      .bind(aptId, contribUser.id, 'contributor', '2026-11-18T12:15:00.000Z')
      .run();

    const contribGet = await app.request(
      `/v1/apartments/${aptId}`,
      { headers: { Authorization: 'Bearer dev:contrib-fb' } },
      env,
    );
    const contribDto = ApartmentDtoSchema.parse(await contribGet.json());
    expect(contribDto.role).toBe('contributor');
    expect(contribDto.inviteCode).toBeNull();
    expect(contribDto.shouldSuggestInviteCodeReset).toBe(false);

    const contribPatch = await app.request(
      `/v1/apartments/${aptId}`,
      {
        method: 'PATCH',
        headers: { Authorization: 'Bearer dev:contrib-fb', 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: 'Hacked' }),
      },
      env,
    );
    expect(contribPatch.status).toBe(HTTP_STATUS.FORBIDDEN);
    expect(ProblemDetailsSchema.parse(await contribPatch.json()).code).toBe(
      'APARTMENT_OWNER_REQUIRED',
    );

    const ownerGet = await app.request(
      `/v1/apartments/${aptId}`,
      { headers: { Authorization: 'Bearer dev:owner-2' } },
      env,
    );
    expect(ApartmentDtoSchema.parse(await ownerGet.json()).shouldSuggestInviteCodeReset).toBe(true);
  });
});
