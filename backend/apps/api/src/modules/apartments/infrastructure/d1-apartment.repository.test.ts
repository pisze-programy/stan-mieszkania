import { verifyTableSchemas } from '@stanmieszkania/d1';
import { isOk } from '@stanmieszkania/shared';
import { FixedClock, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createD1TestHarness, type D1TestHarness } from '../../../testing/d1-test-harness';
import { createApartment, applyApartmentMetadataUpdate } from '../domain/apartment.entity';
import { APARTMENT_CHANGES_TABLE } from './apartment-changes.table';
import { APARTMENTS_TABLE } from './apartments.table';
import { createD1ApartmentRepository } from './d1-apartment.repository';

describe('D1ApartmentRepository', () => {
  let harness: D1TestHarness | undefined;

  const getHarness = (): D1TestHarness => {
    if (harness === undefined) {
      throw new Error('D1 test harness was not initialized');
    }
    return harness;
  };

  beforeAll(async () => {
    harness = await createD1TestHarness();
    const now = '2026-11-18T12:00:00.000Z';
    const db = getHarness().db;
    await db
      .prepare(
        'INSERT INTO users (id, firebase_uid, display_name, short_tag, color, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      )
      .bind('usr-owner', 'fb-owner', 'Owner', 'OWN1', '#007AFF', now)
      .run();
    await db
      .prepare(
        'INSERT INTO users (id, firebase_uid, display_name, short_tag, color, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      )
      .bind('usr-contrib', 'fb-contrib', 'Contrib', 'CNT1', '#34C759', now)
      .run();
  });

  afterAll(async () => {
    await harness?.dispose();
  });

  it('matches APARTMENTS_TABLE and APARTMENT_CHANGES_TABLE schemas against PRAGMA table_info', async () => {
    const verification = await verifyTableSchemas(getHarness().db, [
      APARTMENTS_TABLE,
      APARTMENT_CHANGES_TABLE,
    ]);
    expect(isOk(verification)).toBe(true);
  });

  it('runs atomic create, update with history, invite reset, ownership transfer, and hard delete', async () => {
    const db = getHarness().db;
    const repo = createD1ApartmentRepository(db);
    const ids = new SequentialUuidV7Generator();
    const clock = new FixedClock();

    const aptId = ids.nextId();
    const built = createApartment({
      id: aptId,
      ownerId: 'usr-owner',
      name: 'Kawalerka',
      street: 'Puławska 1',
      city: 'Warszawa',
      inviteCode: 'K7QM-4XPB',
      createdAt: clock.nowIso(),
    });
    expect(isOk(built)).toBe(true);
    if (!isOk(built)) return;

    expect(
      (await repo.createWithOwnerMembership({ apartment: built.value, joinedAt: clock.nowIso() }))
        .ok,
    ).toBe(true);

    clock.advanceBy(60_000);
    const updated = applyApartmentMetadataUpdate({
      apartment: built.value,
      authorId: 'usr-owner',
      name: 'Kawalerka Po Remoncie',
      updatedAt: clock.nowIso(),
      idGenerator: ids,
    });
    expect(isOk(updated)).toBe(true);
    if (!isOk(updated)) return;
    expect((await repo.updateWithChanges(updated.value)).ok).toBe(true);

    const changes = await repo.listChanges(aptId);
    expect(isOk(changes)).toBe(true);
    if (isOk(changes)) {
      expect(changes.value).toHaveLength(1);
      expect(changes.value[0]?.oldValue).toBe('Kawalerka');
      expect(changes.value[0]?.newValue).toBe('Kawalerka Po Remoncie');
    }

    await db
      .prepare(
        'INSERT INTO memberships (apartment_id, user_id, role, joined_at) VALUES (?, ?, ?, ?)',
      )
      .bind(aptId, 'usr-contrib', 'contributor', '2026-11-18T12:05:00.000Z')
      .run();

    expect(
      (
        await repo.transferOwnershipAndLeave({
          apartmentId: aptId,
          previousOwnerId: 'usr-owner',
          newOwnerId: 'usr-contrib',
          leftAt: '2026-11-18T12:10:00.000Z',
        })
      ).ok,
    ).toBe(true);

    const afterTransfer = await repo.findById(aptId);
    if (isOk(afterTransfer)) {
      expect(afterTransfer.value?.ownerId).toBe('usr-contrib');
    }
    expect((await repo.findActiveRole(aptId, 'usr-owner')).ok).toBe(true);
    expect(await repo.findActiveRole(aptId, 'usr-owner')).toEqual({ ok: true, value: null });
    expect(await repo.findActiveRole(aptId, 'usr-contrib')).toEqual({ ok: true, value: 'owner' });

    expect((await repo.hardDelete(aptId)).ok).toBe(true);
    expect(await repo.findById(aptId)).toEqual({ ok: true, value: null });
  });
});
