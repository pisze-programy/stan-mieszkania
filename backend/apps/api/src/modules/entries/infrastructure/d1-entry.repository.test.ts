import { createStatement, execute, query, verifyTableSchemas } from '@stanmieszkania/d1';
import { isOk } from '@stanmieszkania/shared';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { z } from 'zod';
import { createD1TestHarness, type D1TestHarness } from '../../../testing/d1-test-harness';
import { ENTRY_CHANGE_LOG_ENTITY_TYPE, ENTRY_CHANGE_LOG_OPS } from '../domain/entries.constants';
import { createD1EntryRepository } from './d1-entry.repository';
import { ENTRIES_TABLE } from './entries.table';
import { MARKERS_TABLE } from './markers.table';

describe('D1EntryRepository', () => {
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

  it('matches ENTRIES_TABLE and MARKERS_TABLE against 0001_init PRAGMA table_info', async () => {
    const result = await verifyTableSchemas(getHarness().db, [ENTRIES_TABLE, MARKERS_TABLE]);
    expect(result).toEqual({ ok: true, value: undefined });
  });

  it('persists entries/markers with change_log, masks retracted reads, and keeps MAX(number) monotonic', async () => {
    const db = getHarness().db;
    const now = '2026-11-18T14:00:00.000Z';

    expect(
      (
        await execute(
          db,
          createStatement(
            'INSERT INTO users (id, firebase_uid, display_name, short_tag, color, created_at) VALUES (?, ?, ?, ?, ?, ?)',
            ['u-1', 'fb-1', 'Anna', 'ANNA', '#3B82F6', now],
          ),
        )
      ).ok,
    ).toBe(true);
    expect(
      (
        await execute(
          db,
          createStatement(
            'INSERT INTO apartments (id, owner_id, name, street, city, invite_code, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            ['apt-1', 'u-1', 'Flat', 'Main 1', 'Warsaw', 'K7QM-4XPB', now, now],
          ),
        )
      ).ok,
    ).toBe(true);
    expect(
      (
        await execute(
          db,
          createStatement(
            'INSERT INTO memberships (apartment_id, user_id, role, joined_at, left_at) VALUES (?, ?, ?, ?, NULL)',
            ['apt-1', 'u-1', 'owner', now],
          ),
        )
      ).ok,
    ).toBe(true);
    expect(
      (
        await execute(
          db,
          createStatement(
            'INSERT INTO media (id, apartment_id, author_id, kind, source, upload_status, sha256, captured_at, captured_tz, width, height, bytes, r2_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              'm-1',
              'apt-1',
              'u-1',
              'photo',
              'camera',
              'confirmed',
              'a'.repeat(64),
              now,
              'Europe/Warsaw',
              1200,
              800,
              1024,
              'apartments/apt-1/media/m-1.jpg',
            ],
          ),
        )
      ).ok,
    ).toBe(true);

    const repo = createD1EntryRepository(db);
    expect(await repo.getMaxMarkerNumber('m-1')).toEqual({ ok: true, value: 0 });

    const inserted = await repo.insertWithMarkers({
      apartmentId: 'apt-1',
      entry: {
        id: 'e-1',
        mediaId: 'm-1',
        authorId: 'u-1',
        text: 'Defect [1] and [2]',
        markers: [
          { id: 'mk-1', entryId: 'e-1', mediaId: 'm-1', number: 1, x: 0.2, y: 0.3 },
          { id: 'mk-2', entryId: 'e-1', mediaId: 'm-1', number: 2, x: 0.7, y: 0.8 },
        ],
        createdAt: now,
        serverReceivedAt: now,
        retractedAt: null,
      },
    });
    expect(inserted.ok).toBe(true);
    expect(await repo.getMaxMarkerNumber('m-1')).toEqual({ ok: true, value: 2 });

    const retractedAt = '2026-11-18T14:05:00.000Z';
    expect((await repo.retract({ entryId: 'e-1', apartmentId: 'apt-1', retractedAt })).ok).toBe(
      true,
    );

    const afterRetract = await repo.findByIdWithAuthor('e-1');
    expect(isOk(afterRetract)).toBe(true);
    if (isOk(afterRetract)) {
      expect(afterRetract.value?.entry.text).toBe('');
      expect(afterRetract.value?.entry.markers).toEqual([]);
      expect(afterRetract.value?.entry.retractedAt).toBe(retractedAt);
      expect(afterRetract.value?.author.displayName).toBe('Anna');
    }

    expect(await repo.getMaxMarkerNumber('m-1')).toEqual({ ok: true, value: 2 });

    const logs = await query(
      db,
      createStatement(
        'SELECT entity_type, entity_id, op FROM change_log WHERE apartment_id = ? ORDER BY seq ASC',
        ['apt-1'],
      ),
      z.object({ entity_type: z.string(), entity_id: z.string(), op: z.string() }),
    );
    expect(isOk(logs) ? logs.value : []).toEqual([
      {
        entity_type: ENTRY_CHANGE_LOG_ENTITY_TYPE,
        entity_id: 'e-1',
        op: ENTRY_CHANGE_LOG_OPS.CREATED,
      },
      {
        entity_type: ENTRY_CHANGE_LOG_ENTITY_TYPE,
        entity_id: 'e-1',
        op: ENTRY_CHANGE_LOG_OPS.RETRACTED,
      },
    ]);
  });
});
