import {
  DB_ERROR_CODES,
  createStatement,
  defineTable,
  execute,
  query,
  verifyTableSchemas,
  type SqlParam,
  type TableSchemaDescriptor,
} from '@stanmieszkania/d1';
import { isErr, isOk } from '@stanmieszkania/shared';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { z } from 'zod';
import { createD1TestHarness, type D1TestHarness } from './d1-test-harness';

function makeTableDescriptor(name: string, columnsCsv: string): TableSchemaDescriptor {
  const columns = columnsCsv.split(',');
  const columnMap = Object.fromEntries(columns.map((column) => [column, column]));
  const shape = Object.fromEntries(columns.map((column) => [column, z.unknown()]));
  return defineTable({ name, columns: columnMap, rowSchema: z.object(shape) });
}

const EXPECTED_TABLES: readonly TableSchemaDescriptor[] = [
  makeTableDescriptor(
    'users',
    'id,firebase_uid,display_name,short_tag,color,created_at,deleted_at',
  ),
  makeTableDescriptor(
    'apartments',
    'id,owner_id,name,street,city,invite_code,invite_code_rotated_at,cloud_media_count,orphan_delete_after,created_at,updated_at,deleted_at',
  ),
  makeTableDescriptor(
    'apartment_changes',
    'id,apartment_id,author_id,field,old_value,new_value,created_at',
  ),
  makeTableDescriptor('memberships', 'apartment_id,user_id,role,joined_at,left_at'),
  makeTableDescriptor(
    'media',
    'id,apartment_id,author_id,kind,source,upload_status,sha256,captured_at,captured_tz,captured_at_from_import,server_received_at,lat,lng,accuracy_m,location_source,width,height,bytes,r2_key,deleted_at,deleted_by',
  ),
  makeTableDescriptor(
    'entries',
    'id,media_id,author_id,text,created_at,server_received_at,retracted_at',
  ),
  makeTableDescriptor('markers', 'id,entry_id,media_id,number,x,y'),
  makeTableDescriptor('change_log', 'seq,apartment_id,entity_type,entity_id,op,created_at'),
];

const EXPECTED_INDEXES: readonly string[] = [
  'idx_users_firebase_uid',
  'idx_apartments_invite_code',
  'idx_apartment_changes_apartment_created',
  'idx_memberships_user_left',
  'idx_media_apartment_captured',
  'idx_entries_media_created',
  'idx_markers_entry_id',
  'idx_change_log_apartment_seq',
];

describe('0001_init D1 migration and Miniflare harness', () => {
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

  it('applies 0001_init.sql and verifies all 8 tables and indexes', async () => {
    const activeHarness = getHarness();
    expect(activeHarness.appliedMigrations).toContain('0001_init.sql');
    expect(await verifyTableSchemas(activeHarness.db, EXPECTED_TABLES)).toEqual({
      ok: true,
      value: undefined,
    });

    const indexResult = await query(
      activeHarness.db,
      createStatement("SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'"),
      z.object({ name: z.string() }),
    );
    expect(isOk(indexResult)).toBe(true);
    if (isOk(indexResult)) {
      const indexNames = indexResult.value.map((row) => row.name);
      for (const expectedIndex of EXPECTED_INDEXES) {
        expect(indexNames).toContain(expectedIndex);
      }
    }
  });

  it('enforces foreign keys, UNIQUE (media_id, number), change_log seq, and R2 access', async () => {
    const activeHarness = getHarness();
    const now = '2026-11-18T22:00:00.000Z';
    const runSql = (sql: string, params: readonly SqlParam[] = []) =>
      execute(activeHarness.db, createStatement(sql, params));

    const orphanApt = await runSql(
      'INSERT INTO apartments (id, owner_id, name, street, city, invite_code, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      ['apt-bad', 'missing-user', 'Flat', 'Main 1', 'Warsaw', 'CODE-0001', now, now],
    );
    expect(isErr(orphanApt)).toBe(true);
    if (isErr(orphanApt)) {
      expect(orphanApt.error.code).toBe(DB_ERROR_CODES.DB_EXECUTION_FAILED);
    }

    expect(
      isOk(
        await runSql(
          'INSERT INTO users (id, firebase_uid, display_name, short_tag, color, created_at) VALUES (?, ?, ?, ?, ?, ?)',
          ['u-1', 'fb-1', 'Anna', 'A1B2', '#3B82F6', now],
        ),
      ),
    ).toBe(true);
    expect(
      isOk(
        await runSql(
          'INSERT INTO apartments (id, owner_id, name, street, city, invite_code, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          ['apt-1', 'u-1', 'Flat A', 'Marszalkowska 1', 'Warsaw', 'K7QM-4XPB', now, now],
        ),
      ),
    ).toBe(true);
    expect(isErr(await runSql('DELETE FROM users WHERE id = ?', ['u-1']))).toBe(true);

    expect(
      isOk(
        await runSql(
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
            1920,
            1080,
            500000,
            'apt-1/m-1.jpg',
          ],
        ),
      ),
    ).toBe(true);
    expect(
      isOk(
        await runSql(
          'INSERT INTO entries (id, media_id, author_id, text, created_at, server_received_at) VALUES (?, ?, ?, ?, ?, ?)',
          ['e-1', 'm-1', 'u-1', 'Scratch [1]', now, now],
        ),
      ),
    ).toBe(true);
    expect(
      isOk(
        await runSql(
          'INSERT INTO markers (id, entry_id, media_id, number, x, y) VALUES (?, ?, ?, ?, ?, ?)',
          ['mk-1', 'e-1', 'm-1', 1, 0.25, 0.75],
        ),
      ),
    ).toBe(true);
    expect(
      isErr(
        await runSql(
          'INSERT INTO markers (id, entry_id, media_id, number, x, y) VALUES (?, ?, ?, ?, ?, ?)',
          ['mk-2', 'e-1', 'm-1', 1, 0.5, 0.5],
        ),
      ),
    ).toBe(true);

    const changeInsert = await runSql(
      'INSERT INTO change_log (apartment_id, entity_type, entity_id, op, created_at) VALUES (?, ?, ?, ?, ?)',
      ['apt-1', 'media', 'm-1', 'upsert', now],
    );
    expect(changeInsert).toEqual({ ok: true, value: { changes: 1, lastRowId: 1 } });

    await activeHarness.r2.put('apt-1/m-1.jpg', 'jpeg-bytes');
    const object = await activeHarness.r2.get('apt-1/m-1.jpg');
    expect(await object?.text()).toBe('jpeg-bytes');
  });
});
