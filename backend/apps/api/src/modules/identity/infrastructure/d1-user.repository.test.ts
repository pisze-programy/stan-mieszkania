import { verifyTableSchemas } from '@stanmieszkania/d1';
import { isOk } from '@stanmieszkania/shared';
import { FixedClock, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createD1TestHarness, type D1TestHarness } from '../../../testing/d1-test-harness';
import { DELETED_USER_DISPLAY_NAME } from '../domain/identity.constants';
import { createNewUser } from '../domain/user.entity';
import { createD1UserRepository } from './d1-user.repository';
import { USERS_TABLE } from './users.table';

describe('D1UserRepository', () => {
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

  it('matches USERS_TABLE rowSchema and columns against 0001_init PRAGMA table_info', async () => {
    const verification = await verifyTableSchemas(getHarness().db, [USERS_TABLE]);
    expect(isOk(verification)).toBe(true);
  });

  it('inserts, finds by id and firebaseUid, updates displayName, and anonymizes user', async () => {
    const repo = createD1UserRepository(getHarness().db);
    const ids = new SequentialUuidV7Generator();
    const clock = new FixedClock();

    const user = createNewUser({
      id: ids.nextId(),
      firebaseUid: 'firebase-uid-123',
      displayName: 'Krystian',
      createdAt: clock.nowIso(),
    });

    expect((await repo.insert(user)).ok).toBe(true);

    const byId = await repo.findById(user.id);
    expect(isOk(byId)).toBe(true);
    if (isOk(byId)) {
      expect(byId.value).toEqual(user);
    }

    const byUid = await repo.findByFirebaseUid('firebase-uid-123');
    expect(isOk(byUid)).toBe(true);
    if (isOk(byUid)) {
      expect(byUid.value?.id).toBe(user.id);
    }

    expect((await repo.updateDisplayName(user.id, 'Krystian B.')).ok).toBe(true);
    const updated = await repo.findById(user.id);
    if (isOk(updated)) {
      expect(updated.value?.displayName).toBe('Krystian B.');
    }

    clock.advanceBy(60_000);
    const deletedAt = clock.nowIso();
    expect((await repo.anonymize(user.id, deletedAt)).ok).toBe(true);

    const afterDelete = await repo.findById(user.id);
    if (isOk(afterDelete)) {
      expect(afterDelete.value).toEqual({
        ...user,
        firebaseUid: null,
        displayName: DELETED_USER_DISPLAY_NAME,
        deletedAt,
      });
    }

    const byUidAfterDelete = await repo.findByFirebaseUid('firebase-uid-123');
    if (isOk(byUidAfterDelete)) {
      expect(byUidAfterDelete.value).toBeNull();
    }
  });
});
