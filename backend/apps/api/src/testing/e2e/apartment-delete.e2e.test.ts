import { createStatement, queryFirst } from '@stanmieszkania/d1';
import { HTTP_STATUS } from '@stanmieszkania/http-contracts';
import { FixedClock, RecordingLogger, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { z } from 'zod';
import { createApp } from '../../app';
import { buildMediaR2Key } from '../../modules/media';
import { createD1TestHarness, type D1TestHarness } from '../d1-test-harness';
import { putApartment, putEntry, uploadPhoto } from './e2e-actions';
import { buildE2eEnv, createE2eClient, makeJpegBytes } from './e2e-client';

const countRowSchema = z.object({ total: z.number() });

async function countRows(
  harness: D1TestHarness,
  sql: string,
  params: readonly string[],
): Promise<number> {
  const result = await queryFirst(harness.db, createStatement(sql, params), countRowSchema);
  if (!result.ok || result.value === null) {
    throw new Error(`Count query failed: ${sql}`);
  }
  return result.value.total;
}

describe('E2E Populated Apartment Deletion (Miniflare D1 + R2 + ApartmentCoordinator + UserGuard)', () => {
  let harness: D1TestHarness | undefined;

  beforeAll(async () => {
    harness = await createD1TestHarness();
  });

  afterAll(async () => {
    await harness?.dispose();
  });

  it('hard-deletes sole-owner apartment with media, entries, markers, changes, memberships, change_log, and R2 objects', async () => {
    if (harness === undefined) throw new Error('D1 test harness was not initialized');
    const h = harness;
    const clock = new FixedClock(new Date(Date.now() + 7 * 86_400_000).toISOString());
    const ids = new SequentialUuidV7Generator();
    const app = createApp({
      overrides: { clock, idGenerator: ids, logger: new RecordingLogger() },
    });
    const env = buildE2eEnv(h);
    const client = createE2eClient((req) => app.fetch(req, env));
    const owner = 'dev:pop-delete-owner:Krzysztof';

    const aptId = ids.nextId();
    await putApartment(client, owner, aptId, {
      name: 'Mieszkanie Do Usunięcia',
      street: 'Mokotowska 12',
      city: 'Warszawa',
    });

    const patchRes = await client.request(`/v1/apartments/${aptId}`, {
      method: 'PATCH',
      token: owner,
      json: { name: 'Mieszkanie Zmienione' },
    });
    expect(patchRes.status).toBe(HTTP_STATUS.OK);

    const photo1Id = ids.nextId();
    const photo2Id = ids.nextId();
    await uploadPhoto(client, {
      token: owner,
      apartmentId: aptId,
      mediaId: photo1Id,
      bytes: makeJpegBytes(1, 2),
      capturedAt: clock.nowIso(),
    });
    await uploadPhoto(client, {
      token: owner,
      apartmentId: aptId,
      mediaId: photo2Id,
      bytes: makeJpegBytes(3, 4),
      capturedAt: clock.nowIso(),
    });

    await putEntry(client, {
      token: owner,
      apartmentId: aptId,
      mediaId: photo1Id,
      entryId: ids.nextId(),
      text: 'Rysa [1] i ubytek [2]',
      createdAt: clock.nowIso(),
      markers: [
        { id: ids.nextId(), localNumber: 1, x: 0.2, y: 0.3 },
        { id: ids.nextId(), localNumber: 2, x: 0.6, y: 0.7 },
      ],
    });
    await putEntry(client, {
      token: owner,
      apartmentId: aptId,
      mediaId: photo2Id,
      entryId: ids.nextId(),
      text: 'Plama [1]',
      createdAt: clock.nowIso(),
      markers: [{ id: ids.nextId(), localNumber: 1, x: 0.5, y: 0.5 }],
    });

    const r2Key1 = buildMediaR2Key(aptId, photo1Id);
    const r2Key2 = buildMediaR2Key(aptId, photo2Id);
    expect(await h.r2.head(r2Key1)).not.toBeNull();
    expect(await h.r2.head(r2Key2)).not.toBeNull();

    const preCounts = await Promise.all([
      countRows(h, 'SELECT COUNT(*) AS total FROM apartments WHERE id = ?', [aptId]),
      countRows(h, 'SELECT COUNT(*) AS total FROM memberships WHERE apartment_id = ?', [aptId]),
      countRows(h, 'SELECT COUNT(*) AS total FROM apartment_changes WHERE apartment_id = ?', [
        aptId,
      ]),
      countRows(h, 'SELECT COUNT(*) AS total FROM media WHERE apartment_id = ?', [aptId]),
      countRows(h, 'SELECT COUNT(*) AS total FROM entries WHERE media_id IN (?, ?)', [
        photo1Id,
        photo2Id,
      ]),
      countRows(h, 'SELECT COUNT(*) AS total FROM markers WHERE media_id IN (?, ?)', [
        photo1Id,
        photo2Id,
      ]),
      countRows(h, 'SELECT COUNT(*) AS total FROM change_log WHERE apartment_id = ?', [aptId]),
    ]);
    expect(preCounts).toEqual([1, 1, 1, 2, 2, 3, 8]);

    const deleteRes = await client.request(`/v1/apartments/${aptId}`, {
      method: 'DELETE',
      token: owner,
    });
    expect(deleteRes.status).toBe(HTTP_STATUS.NO_CONTENT);
    expect(await deleteRes.text()).toBe('');

    const postCounts = await Promise.all([
      countRows(h, 'SELECT COUNT(*) AS total FROM apartments WHERE id = ?', [aptId]),
      countRows(h, 'SELECT COUNT(*) AS total FROM memberships WHERE apartment_id = ?', [aptId]),
      countRows(h, 'SELECT COUNT(*) AS total FROM apartment_changes WHERE apartment_id = ?', [
        aptId,
      ]),
      countRows(h, 'SELECT COUNT(*) AS total FROM media WHERE apartment_id = ?', [aptId]),
      countRows(h, 'SELECT COUNT(*) AS total FROM entries WHERE media_id IN (?, ?)', [
        photo1Id,
        photo2Id,
      ]),
      countRows(h, 'SELECT COUNT(*) AS total FROM markers WHERE media_id IN (?, ?)', [
        photo1Id,
        photo2Id,
      ]),
      countRows(h, 'SELECT COUNT(*) AS total FROM change_log WHERE apartment_id = ?', [aptId]),
    ]);
    expect(postCounts).toEqual([0, 0, 0, 0, 0, 0, 0]);
    expect(await h.r2.head(r2Key1)).toBeNull();
    expect(await h.r2.head(r2Key2)).toBeNull();

    const afterGet = await client.request(`/v1/apartments/${aptId}`, { token: owner });
    expect(afterGet.status).toBe(HTTP_STATUS.NOT_FOUND);
  });
});
