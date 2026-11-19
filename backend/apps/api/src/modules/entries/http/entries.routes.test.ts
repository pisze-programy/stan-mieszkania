import { createStatement, execute } from '@stanmieszkania/d1';
import { HTTP_STATUS, ProblemDetailsSchema } from '@stanmieszkania/http-contracts';
import { FixedClock, RecordingLogger, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../../../app';
import { createD1TestHarness, type D1TestHarness } from '../../../testing/d1-test-harness';
import { ApartmentDtoSchema } from '../../apartments';
import { ENTRY_ERROR_CODES } from '../domain/entries.errors';
import { EntryDtoSchema, EntryListResponseSchema } from './entries.schema';

const authHeaders = (token: string) => ({
  Authorization: `Bearer ${token}`,
  'content-type': 'application/json',
});

describe('Entries HTTP routes (/v1/apartments/:apartmentId/media/:mediaId/entries)', () => {
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

  it('runs multi-author numbering [1],[2] -> [3], idempotent replay, retraction masking, monotonic [4], and auth guards', async () => {
    const clock = new FixedClock('2026-11-18T15:00:00.000Z');
    const ids = new SequentialUuidV7Generator();
    const app = createApp({
      overrides: { clock, idGenerator: ids, logger: new RecordingLogger() },
    });
    const env = { DB: getHarness().db, MEDIA_BUCKET: getHarness().r2, AUTH_MODE: 'local' };
    const ownerAuth = authHeaders('dev:entry-owner:Anna');
    const contribAuth = authHeaders('dev:entry-contrib:Piotr');
    const outsiderAuth = authHeaders('dev:entry-outsider:Marek');

    const aptId = ids.nextId();
    const aptRes = await app.request(
      `/v1/apartments/${aptId}`,
      {
        method: 'PUT',
        headers: ownerAuth,
        body: JSON.stringify({ name: 'Flat', street: 'Main 1', city: 'Warsaw' }),
      },
      env,
    );
    expect(aptRes.status).toBe(HTTP_STATUS.OK);
    const apt = ApartmentDtoSchema.parse(await aptRes.json());

    const joinRes = await app.request(
      '/v1/apartments/join',
      {
        method: 'POST',
        headers: contribAuth,
        body: JSON.stringify({ inviteCode: apt.inviteCode }),
      },
      env,
    );
    expect(joinRes.status).toBe(HTTP_STATUS.OK);

    const mediaId = ids.nextId();
    expect(
      (
        await execute(
          getHarness().db,
          createStatement(
            'INSERT INTO media (id, apartment_id, author_id, kind, source, upload_status, sha256, captured_at, captured_tz, width, height, bytes, r2_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              mediaId,
              apt.id,
              apt.ownerId,
              'photo',
              'camera',
              'confirmed',
              'b'.repeat(64),
              clock.nowIso(),
              'Europe/Warsaw',
              1200,
              800,
              2048,
              `apartments/${apt.id}/media/${mediaId}.jpg`,
            ],
          ),
        )
      ).ok,
    ).toBe(true);

    const basePath = `/v1/apartments/${apt.id}/media/${mediaId}/entries`;
    const e1Id = ids.nextId();
    const e1Res = await app.request(
      `${basePath}/${e1Id}`,
      {
        method: 'PUT',
        headers: ownerAuth,
        body: JSON.stringify({
          text: 'Crack [1] and scuff [2]',
          createdAt: '2026-11-18T14:58:00.000Z',
          markers: [
            { id: ids.nextId(), localNumber: 1, x: 0.1, y: 0.2 },
            { id: ids.nextId(), localNumber: 2, x: 0.8, y: 0.7 },
          ],
        }),
      },
      env,
    );
    expect(e1Res.status).toBe(HTTP_STATUS.OK);
    const e1 = EntryDtoSchema.parse(await e1Res.json());
    expect(e1.markers.map((m) => m.number)).toEqual([1, 2]);
    expect(e1.author.role).toBe('owner');

    clock.advanceBy(2_000);
    const e2Id = ids.nextId();
    const e2Body = JSON.stringify({
      text: 'Contributor note [1]',
      createdAt: '2026-11-18T14:59:00.000Z',
      markers: [{ id: ids.nextId(), localNumber: 1, x: 0.45, y: 0.55 }],
    });
    const e2Res = await app.request(
      `${basePath}/${e2Id}`,
      { method: 'PUT', headers: contribAuth, body: e2Body },
      env,
    );
    expect(e2Res.status).toBe(HTTP_STATUS.OK);
    const e2 = EntryDtoSchema.parse(await e2Res.json());
    expect(e2.text).toBe('Contributor note [3]');
    expect(e2.markers.map((m) => m.number)).toEqual([3]);
    expect(e2.author.role).toBe('contributor');

    const replayRes = await app.request(
      `${basePath}/${e2Id}`,
      { method: 'PUT', headers: contribAuth, body: e2Body },
      env,
    );
    expect(replayRes.status).toBe(HTTP_STATUS.OK);
    expect(EntryDtoSchema.parse(await replayRes.json())).toEqual(e2);

    const conflictRes = await app.request(
      `${basePath}/${e2Id}`,
      { method: 'PUT', headers: ownerAuth, body: e2Body },
      env,
    );
    expect(conflictRes.status).toBe(HTTP_STATUS.CONFLICT);
    expect(ProblemDetailsSchema.parse(await conflictRes.json()).code).toBe(
      ENTRY_ERROR_CODES.ENTRY_CONFLICT,
    );

    const ownerRetractContrib = await app.request(
      `${basePath}/${e2Id}`,
      { method: 'DELETE', headers: ownerAuth },
      env,
    );
    expect(ownerRetractContrib.status).toBe(HTTP_STATUS.FORBIDDEN);
    expect(ProblemDetailsSchema.parse(await ownerRetractContrib.json()).code).toBe(
      ENTRY_ERROR_CODES.ENTRY_AUTHOR_REQUIRED,
    );

    clock.advanceBy(3_000);
    const retractRes = await app.request(
      `${basePath}/${e2Id}`,
      { method: 'DELETE', headers: contribAuth },
      env,
    );
    expect(retractRes.status).toBe(HTTP_STATUS.OK);
    const retracted = EntryDtoSchema.parse(await retractRes.json());
    expect(retracted.text).toBe('');
    expect(retracted.markers).toEqual([]);
    expect(retracted.retractedAt).toBe(clock.nowIso());

    clock.advanceBy(1_000);
    const e3Id = ids.nextId();
    const e3Res = await app.request(
      `${basePath}/${e3Id}`,
      {
        method: 'PUT',
        headers: ownerAuth,
        body: JSON.stringify({
          text: 'Follow-up [1]',
          createdAt: '2026-11-18T15:01:00.000Z',
          markers: [{ id: ids.nextId(), localNumber: 1, x: 0.9, y: 0.1 }],
        }),
      },
      env,
    );
    expect(e3Res.status).toBe(HTTP_STATUS.OK);
    const e3 = EntryDtoSchema.parse(await e3Res.json());
    expect(e3.text).toBe('Follow-up [4]');
    expect(e3.markers.map((m) => m.number)).toEqual([4]);

    const listRes = await app.request(basePath, { headers: contribAuth }, env);
    expect(listRes.status).toBe(HTTP_STATUS.OK);
    const { items } = EntryListResponseSchema.parse(await listRes.json());
    expect(items.map((item) => [item.id, item.text, item.markers.map((m) => m.number)])).toEqual([
      [e1Id, 'Crack [1] and scuff [2]', [1, 2]],
      [e2Id, '', []],
      [e3Id, 'Follow-up [4]', [4]],
    ]);

    const outsiderRes = await app.request(basePath, { headers: outsiderAuth }, env);
    expect(outsiderRes.status).toBe(HTTP_STATUS.FORBIDDEN);
    expect(ProblemDetailsSchema.parse(await outsiderRes.json()).code).toBe(
      ENTRY_ERROR_CODES.ENTRY_ACCESS_DENIED,
    );
  });
});
