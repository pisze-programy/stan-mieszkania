import { createStatement, execute, query, queryFirst } from '@stanmieszkania/d1';
import { HTTP_STATUS } from '@stanmieszkania/http-contracts';
import { FixedClock, RecordingLogger, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { z } from 'zod';
import { createApp } from '../app';
import { ApartmentDtoSchema, type ApartmentDto } from '../modules/apartments';
import { createD1TestHarness, type D1TestHarness } from '../testing/d1-test-harness';
import { createDurableObjectApartmentCommandGateway } from './apartment-coordinator.gateway';

const idRowSchema = z.object({ id: z.string() });
const countRowSchema = z.object({ cloud_media_count: z.number() });
const changeOpRowSchema = z.object({ entity_id: z.string(), op: z.string() });

const INSERT_MEDIA_SQL =
  'INSERT INTO media (id, apartment_id, author_id, kind, source, upload_status, sha256, captured_at, captured_tz, width, height, bytes, r2_key, deleted_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
const INSERT_LOG_SQL =
  'INSERT INTO change_log (apartment_id, entity_type, entity_id, op, created_at) VALUES (?, ?, ?, ?, ?)';

async function createTestApartment(
  h: D1TestHarness,
  ids: SequentialUuidV7Generator,
  clockIso: string,
  token: string,
): Promise<ApartmentDto> {
  const app = createApp({
    overrides: { clock: new FixedClock(clockIso), idGenerator: ids, logger: new RecordingLogger() },
  });
  const env = {
    DB: h.db,
    MEDIA_BUCKET: h.r2,
    USER_GUARD: h.userGuard,
    APARTMENT_COORDINATOR: h.apartmentCoordinator,
    AUTH_MODE: 'local',
  };
  const res = await app.request(
    `/v1/apartments/${ids.nextId()}`,
    {
      method: 'PUT',
      headers: { Authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify({ name: 'Flat', street: 'Main 1', city: 'Warsaw' }),
    },
    env,
  );
  expect(res.status).toBe(HTTP_STATUS.OK);
  return ApartmentDtoSchema.parse(await res.json());
}

async function seedMedia(
  h: D1TestHarness,
  apt: ApartmentDto,
  id: string,
  status: 'pending' | 'confirmed',
  capturedAt: string,
  deletedAt: string | null,
  hashChar: string,
  pendingLogAt?: string,
): Promise<string> {
  const r2Key = `apartments/${apt.id}/media/${id}.jpg`;
  await h.r2.put(r2Key, new Uint8Array([1, 2, 3]));
  await execute(
    h.db,
    createStatement(INSERT_MEDIA_SQL, [
      id,
      apt.id,
      apt.ownerId,
      'photo',
      'camera',
      status,
      hashChar.repeat(64),
      capturedAt,
      'Europe/Warsaw',
      800,
      600,
      100,
      r2Key,
      deletedAt,
    ]),
  );
  if (pendingLogAt !== undefined) {
    await execute(
      h.db,
      createStatement(INSERT_LOG_SQL, [apt.id, 'media', id, 'pending', pendingLogAt]),
    );
  }
  return r2Key;
}

describe('ApartmentCoordinator DO alarm maintenance jobs (Miniflare D1 + R2 + DO)', () => {
  let harness: D1TestHarness | undefined;
  const ids = new SequentialUuidV7Generator();
  beforeAll(async () => {
    harness = await createD1TestHarness();
  });
  afterAll(async () => {
    await harness?.dispose();
  });

  it('reclaims 24h-abandoned pending uploads while preserving fresh old-EXIF pending, confirmed, and soft-deleted media', async () => {
    if (harness === undefined) throw new Error('D1 test harness was not initialized');
    const h = harness;
    const baseMs = Date.now() + 7 * 86_400_000;
    const apt = await createTestApartment(h, ids, new Date(baseMs).toISOString(), 'dev:alarm:Ewa');

    const oldIso = new Date(baseMs - 25 * 3_600_000).toISOString();
    const freshIso = new Date(baseMs - 1 * 3_600_000).toISOString();
    const abandonedId = ids.nextId();
    const freshId = ids.nextId();
    const confirmedId = ids.nextId();
    const softDeletedId = ids.nextId();

    const abandonedKey = await seedMedia(h, apt, abandonedId, 'pending', oldIso, null, '1', oldIso);
    const abandonedEntryId = ids.nextId();
    await h.db.batch([
      h.db
        .prepare(
          'INSERT INTO entries (id, media_id, author_id, text, created_at, server_received_at) VALUES (?, ?, ?, ?, ?, ?)',
        )
        .bind(abandonedEntryId, abandonedId, apt.ownerId, 'Draft [1]', oldIso, oldIso),
      h.db
        .prepare(
          'INSERT INTO markers (id, entry_id, media_id, number, x, y) VALUES (?, ?, ?, ?, ?, ?)',
        )
        .bind(ids.nextId(), abandonedEntryId, abandonedId, 1, 0.5, 0.5),
      h.db.prepare('UPDATE apartments SET cloud_media_count = 4 WHERE id = ?').bind(apt.id),
    ]);
    const freshKey = await seedMedia(
      h,
      apt,
      freshId,
      'pending',
      '2022-05-01T10:00:00.000Z',
      null,
      '2',
      freshIso,
    );
    const confirmedKey = await seedMedia(h, apt, confirmedId, 'confirmed', oldIso, null, '3');
    const softDeletedKey = await seedMedia(h, apt, softDeletedId, 'confirmed', oldIso, oldIso, '4');

    const gateway = createDurableObjectApartmentCommandGateway(h.apartmentCoordinator);
    await gateway.schedulePendingUploadCleanup(apt.id, baseMs, 24 * 3_600_000);
    const result = await gateway.runMaintenanceNow(apt.id, baseMs);

    expect(result).toEqual({
      apartmentPurged: false,
      cleanedPendingMediaCount: 1,
      nextAlarmMs: Date.parse(freshIso) + 24 * 3_600_000,
    });
    expect(await h.r2.head(abandonedKey)).toBeNull();
    expect(await h.r2.head(freshKey)).not.toBeNull();
    expect(await h.r2.head(confirmedKey)).not.toBeNull();
    expect(await h.r2.head(softDeletedKey)).not.toBeNull();

    const remaining = await query(
      h.db,
      createStatement('SELECT id FROM media WHERE apartment_id = ? ORDER BY id ASC', [apt.id]),
      idRowSchema,
    );
    expect(remaining.ok && remaining.value.map((r) => r.id)).toEqual(
      [freshId, confirmedId, softDeletedId].sort(),
    );
    const aptCount = await queryFirst(
      h.db,
      createStatement('SELECT cloud_media_count FROM apartments WHERE id = ?', [apt.id]),
      countRowSchema,
    );
    expect(aptCount.ok && aptCount.value?.cloud_media_count).toBe(3);
    const logs = await query(
      h.db,
      createStatement('SELECT entity_id, op FROM change_log WHERE apartment_id = ? AND op = ?', [
        apt.id,
        'abandoned_cleaned',
      ]),
      changeOpRowSchema,
    );
    expect(logs.ok && logs.value).toEqual([{ entity_id: abandonedId, op: 'abandoned_cleaned' }]);
  });

  it('hard-deletes expired 30-day orphaned apartments and removes all R2 objects on alarm execution', async () => {
    if (harness === undefined) throw new Error('D1 test harness was not initialized');
    const h = harness;
    const createdMs = Date.now() + 7 * 86_400_000;
    const createdIso = new Date(createdMs).toISOString();
    const orphanAfterMs = createdMs + 30 * 86_400_000;
    const orphanAfterIso = new Date(orphanAfterMs).toISOString();
    const apt = await createTestApartment(h, ids, createdIso, 'dev:orphan:Tomek');
    const r2Key = await seedMedia(h, apt, ids.nextId(), 'confirmed', createdIso, null, '9');
    await execute(
      h.db,
      createStatement('UPDATE apartments SET orphan_delete_after = ? WHERE id = ?', [
        orphanAfterIso,
        apt.id,
      ]),
    );

    const gateway = createDurableObjectApartmentCommandGateway(h.apartmentCoordinator);
    await gateway.scheduleOrphanPurge(apt.id, orphanAfterMs);
    const result = await gateway.runMaintenanceNow(apt.id, orphanAfterMs + 86_400_000);

    expect(result).toEqual({
      apartmentPurged: true,
      cleanedPendingMediaCount: 0,
      nextAlarmMs: null,
    });
    expect(await h.r2.head(r2Key)).toBeNull();
    const row = await queryFirst(
      h.db,
      createStatement('SELECT id FROM apartments WHERE id = ?', [apt.id]),
      idRowSchema,
    );
    expect(row.ok && row.value).toBeNull();
  });
});
