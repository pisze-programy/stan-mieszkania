import { verifyTableSchemas } from '@stanmieszkania/d1';
import { exhaustCursorPages, isErr, isOk } from '@stanmieszkania/shared';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createD1TestHarness, type D1TestHarness } from '../../../testing/d1-test-harness';
import { createPendingMedia } from '../domain/media.entity';
import { MEDIA_ERROR_CODES } from '../domain/media.errors';
import type { MediaWithAuthor } from '../domain/media.repository';
import { createD1MediaRepository } from './d1-media.repository';
import { MEDIA_TABLE } from './media.table';

describe('D1MediaRepository', () => {
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

  it('matches MEDIA_TABLE schema against PRAGMA table_info', async () => {
    const verification = await verifyTableSchemas(getHarness().db, [MEDIA_TABLE]);
    expect(isOk(verification)).toBe(true);
  });

  it('enforces SQL quota guard, maps DB confirmed <-> uploaded, paginates timeline, and preserves quota on soft-delete', async () => {
    const db = getHarness().db;
    const repo = createD1MediaRepository(db);
    const quota = 2;

    for (const [index, capturedAt] of [
      '2026-11-18T12:01:00.000Z',
      '2026-11-18T12:02:00.000Z',
    ].entries()) {
      const built = createPendingMedia({
        id: `med-${String(index + 1)}`,
        apartmentId: 'apt-1',
        authorId: 'usr-owner',
        kind: 'photo',
        source: 'camera',
        sha256: 'a'.repeat(64),
        capturedAt,
        capturedTz: 'Europe/Warsaw',
        capturedAtFromImport: false,
        location: { lat: 52.23, lng: 21.01, accuracyM: 5, locationSource: 'device' },
        width: 800,
        height: 600,
        bytes: 50_000,
        maxBytes: 3_145_728,
      });
      expect(isOk(built)).toBe(true);
      if (!isOk(built)) return;
      expect(
        (await repo.reservePendingSlot({ media: built.value, quota, createdAt: capturedAt })).ok,
      ).toBe(true);
    }

    const overflow = createPendingMedia({
      id: 'med-3',
      apartmentId: 'apt-1',
      authorId: 'usr-owner',
      kind: 'photo',
      source: 'import',
      sha256: 'b'.repeat(64),
      capturedAt: '2026-11-18T12:03:00.000Z',
      capturedTz: 'Europe/Warsaw',
      capturedAtFromImport: true,
      location: null,
      width: 800,
      height: 600,
      bytes: 50_000,
      maxBytes: 3_145_728,
    });
    if (isOk(overflow)) {
      const overResult = await repo.reservePendingSlot({
        media: overflow.value,
        quota,
        createdAt: '2026-11-18T12:03:00.000Z',
      });
      expect(isErr(overResult) && overResult.error.code).toBe(MEDIA_ERROR_CODES.QUOTA_EXCEEDED);
    }

    expect(
      (
        await repo.markUploaded({
          mediaId: 'med-1',
          apartmentId: 'apt-1',
          serverReceivedAt: '2026-11-18T12:04:00.000Z',
        })
      ).ok,
    ).toBe(true);
    const loaded = await repo.findById('med-1');
    expect(isOk(loaded) && loaded.value?.uploadStatus).toBe('uploaded');
    expect(isOk(loaded) && loaded.value?.location?.lat).toBe(52.23);

    expect(
      (
        await repo.softDelete({
          mediaId: 'med-1',
          apartmentId: 'apt-1',
          deletedBy: 'usr-owner',
          deletedAt: '2026-11-18T12:05:00.000Z',
        })
      ).ok,
    ).toBe(true);

    const access = await repo.findApartmentAccess('apt-1', 'usr-owner');
    expect(isOk(access) && access.value?.cloudMediaCount).toBe(2);

    const allPages = await exhaustCursorPages<MediaWithAuthor, string>(async (after) => {
      const page = await repo.listByApartment({
        apartmentId: 'apt-1',
        viewerUserId: 'usr-owner',
        ...(after !== undefined ? { after } : {}),
        limit: 1,
      });
      if (!isOk(page)) throw new Error(page.error.message);
      return page.value;
    });
    expect(allPages.map((item) => item.media.id)).toEqual(['med-2', 'med-1']);

    const logRows = await db
      .prepare(
        'SELECT entity_type, entity_id, op FROM change_log WHERE apartment_id = ? ORDER BY seq ASC',
      )
      .bind('apt-1')
      .all<{ entity_type: string; entity_id: string; op: string }>();
    expect(logRows.results.map((r) => r.op)).toEqual([
      'pending',
      'pending',
      'confirmed',
      'soft_deleted',
    ]);
  });
});
