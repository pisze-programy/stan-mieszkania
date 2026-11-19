import { verifyTableSchemas } from '@stanmieszkania/d1';
import { isOk } from '@stanmieszkania/shared';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createD1TestHarness, type D1TestHarness } from '../../../testing/d1-test-harness';
import { APARTMENT_CHANGES_TABLE, APARTMENTS_TABLE } from '../../apartments';
import { ENTRIES_TABLE, MARKERS_TABLE } from '../../entries';
import { USERS_TABLE } from '../../identity';
import { MEDIA_TABLE } from '../../media';
import { MEMBERSHIPS_TABLE } from '../../membership';
import { CHANGE_LOG_TABLE } from './change-log.table';
import { createD1SyncRepository } from './d1-sync.repository';

describe('D1SyncRepository & all 8 schema tables', () => {
  let harness: D1TestHarness | undefined;

  const getHarness = (): D1TestHarness => {
    if (harness === undefined) throw new Error('D1 test harness was not initialized');
    return harness;
  };

  beforeAll(async () => {
    harness = await createD1TestHarness();
  });

  afterAll(async () => {
    await harness?.dispose();
  });

  it('verifies all 8 module TableSchemaDescriptors against 0001_init.sql', async () => {
    const verification = await verifyTableSchemas(getHarness().db, [
      USERS_TABLE,
      APARTMENTS_TABLE,
      APARTMENT_CHANGES_TABLE,
      MEMBERSHIPS_TABLE,
      MEDIA_TABLE,
      ENTRIES_TABLE,
      MARKERS_TABLE,
      CHANGE_LOG_TABLE,
    ]);
    expect(isOk(verification)).toBe(true);
  });

  it('hydrates change_log pages and computes /v1/me/apartments headSeq', async () => {
    const db = getHarness().db;
    const repo = createD1SyncRepository(db);
    const now = '2026-11-18T12:00:00.000Z';

    await db
      .prepare(
        'INSERT INTO users (id, firebase_uid, display_name, short_tag, color, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      )
      .bind('usr-1', 'fb-1', 'Jan', 'JAN1', '#007AFF', now)
      .run();
    await db
      .prepare(
        'INSERT INTO apartments (id, owner_id, name, street, city, invite_code, cloud_media_count, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?)',
      )
      .bind('apt-1', 'usr-1', 'M1', 'S1', 'Warszawa', 'K7QM-4XPB', now, now)
      .run();
    await db
      .prepare(
        'INSERT INTO memberships (apartment_id, user_id, role, joined_at) VALUES (?, ?, ?, ?)',
      )
      .bind('apt-1', 'usr-1', 'owner', now)
      .run();
    await db
      .prepare(
        'INSERT INTO change_log (apartment_id, entity_type, entity_id, op, created_at) VALUES (?, ?, ?, ?, ?)',
      )
      .bind('apt-1', 'apartment', 'apt-1', 'created', now)
      .run();

    const page = await repo.listChangesAfter({
      apartmentId: 'apt-1',
      callerRole: 'owner',
      afterSeq: 0,
      limit: 10,
    });
    expect(isOk(page)).toBe(true);
    if (isOk(page)) {
      expect(page.value.changes).toHaveLength(1);
      expect(page.value.changes[0]?.payload?.kind).toBe('apartment');
    }

    const mine = await repo.listMyApartmentsSync('usr-1');
    expect(isOk(mine)).toBe(true);
    if (isOk(mine)) {
      expect(mine.value).toHaveLength(1);
      expect(mine.value[0]?.headSeq).toBe(1);
      expect(mine.value[0]?.confirmedMediaCount).toBe(0);
    }
  });
});
