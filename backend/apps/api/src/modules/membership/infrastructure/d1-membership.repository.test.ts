import { verifyTableSchemas } from '@stanmieszkania/d1';
import { isOk } from '@stanmieszkania/shared';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createD1TestHarness, type D1TestHarness } from '../../../testing/d1-test-harness';
import { createD1MembershipRepository } from './d1-membership.repository';
import { MEMBERSHIPS_TABLE } from './memberships.table';

describe('D1MembershipRepository', () => {
  let harness: D1TestHarness | undefined;

  const getHarness = (): D1TestHarness => {
    if (harness === undefined) {
      throw new Error('D1 test harness was not initialized');
    }
    return harness;
  };

  beforeAll(async () => {
    harness = await createD1TestHarness();
    const db = getHarness().db;
    const now = '2026-11-18T12:00:00.000Z';
    await db
      .prepare(
        'INSERT INTO users (id, firebase_uid, display_name, short_tag, color, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      )
      .bind('usr-owner', 'fb-owner', 'Jan', 'JAN1', '#007AFF', now)
      .run();
    await db
      .prepare(
        'INSERT INTO users (id, firebase_uid, display_name, short_tag, color, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      )
      .bind('usr-contrib', 'fb-contrib', 'Anna', 'ANN2', '#34C759', now)
      .run();
    await db
      .prepare(
        'INSERT INTO apartments (id, owner_id, name, street, city, invite_code, cloud_media_count, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?)',
      )
      .bind('apt-1', 'usr-owner', 'M1', 'S1', 'Warszawa', 'K7QM-4XPB', now, now)
      .run();
    await db
      .prepare(
        'INSERT INTO memberships (apartment_id, user_id, role, joined_at) VALUES (?, ?, ?, ?)',
      )
      .bind('apt-1', 'usr-owner', 'owner', now)
      .run();
  });

  afterAll(async () => {
    await harness?.dispose();
  });

  it('matches MEMBERSHIPS_TABLE schema against PRAGMA table_info', async () => {
    const verification = await verifyTableSchemas(getHarness().db, [MEMBERSHIPS_TABLE]);
    expect(isOk(verification)).toBe(true);
  });

  it('persists join, member list, revoke, reactivation, and leave with atomic change_log rows', async () => {
    const db = getHarness().db;
    const repo = createD1MembershipRepository(db);

    expect((await repo.apartmentExists('apt-1')).ok).toBe(true);
    const byCode = await repo.findApartmentByInviteCode('K7QM-4XPB');
    expect(isOk(byCode) && byCode.value?.id).toBe('apt-1');

    expect(
      (
        await repo.joinAsContributor({
          apartmentId: 'apt-1',
          userId: 'usr-contrib',
          joinedAt: '2026-11-18T12:05:00.000Z',
          reactivateExisting: false,
        })
      ).ok,
    ).toBe(true);

    const members = await repo.listByApartment('apt-1');
    expect(isOk(members)).toBe(true);
    if (isOk(members)) {
      expect(members.value).toHaveLength(2);
      expect(members.value[1]).toMatchObject({
        userId: 'usr-contrib',
        displayName: 'Anna',
        shortTag: 'ANN2',
        color: '#34C759',
        role: 'contributor',
        leftAt: null,
      });
    }

    expect(
      (
        await repo.markLeft({
          apartmentId: 'apt-1',
          userId: 'usr-contrib',
          leftAt: '2026-11-18T12:10:00.000Z',
          op: 'revoked',
        })
      ).ok,
    ).toBe(true);

    expect(
      (
        await repo.joinAsContributor({
          apartmentId: 'apt-1',
          userId: 'usr-contrib',
          joinedAt: '2026-11-18T12:15:00.000Z',
          reactivateExisting: true,
        })
      ).ok,
    ).toBe(true);

    expect(
      (
        await repo.markLeft({
          apartmentId: 'apt-1',
          userId: 'usr-contrib',
          leftAt: '2026-11-18T12:20:00.000Z',
          op: 'left',
        })
      ).ok,
    ).toBe(true);

    const logRows = await db
      .prepare(
        'SELECT entity_type, entity_id, op FROM change_log WHERE apartment_id = ? ORDER BY seq ASC',
      )
      .bind('apt-1')
      .all<{ entity_type: string; entity_id: string; op: string }>();
    expect(logRows.results.map((r) => r.op)).toEqual(['joined', 'revoked', 'joined', 'left']);
  });
});
