import { exhaustCursorPages, isErr, isOk } from '@stanmieszkania/shared';
import { describe, expect, it } from 'vitest';
import { createListApartmentChangesFeedUseCase } from './list-apartment-changes-feed.use-case';
import { createListMyApartmentsSyncUseCase } from './list-my-apartments-sync.use-case';
import { SYNC_ERROR_CODES } from '../domain/sync.errors';
import { InMemorySyncRepository } from '../testing/in-memory-sync.repository';

function setupRepo() {
  const repo = new InMemorySyncRepository();
  const now = '2026-11-18T12:00:00.000Z';
  repo.seedApartment({
    id: 'apt-1',
    ownerId: 'usr-own',
    name: 'M1',
    street: 'S1',
    city: 'Warszawa',
    inviteCode: 'K7QM-4XPB',
    inviteCodeRotatedAt: null,
    cloudMediaCount: 1,
    createdAt: now,
    updatedAt: now,
  });
  repo.seedMember('apt-1', {
    userId: 'usr-own',
    displayName: 'Jan',
    shortTag: 'JAN1',
    color: '#007AFF',
    role: 'owner',
    joinedAt: now,
    leftAt: null,
  });
  repo.seedMember('apt-1', {
    userId: 'usr-cnt',
    displayName: 'Anna',
    shortTag: 'ANN2',
    color: '#34C759',
    role: 'contributor',
    joinedAt: '2026-11-18T12:01:00.000Z',
    leftAt: null,
  });
  repo.seedMedia({
    id: 'med-1',
    apartmentId: 'apt-1',
    authorId: 'usr-cnt',
    kind: 'photo',
    source: 'camera',
    uploadStatus: 'uploaded',
    sha256: 'a'.repeat(64),
    capturedAt: '2026-11-18T12:02:00.000Z',
    capturedTz: 'Europe/Warsaw',
    capturedAtFromImport: false,
    serverReceivedAt: '2026-11-18T12:03:00.000Z',
    width: 1200,
    height: 800,
    bytes: 50_000,
    deletedAt: null,
    deletedBy: null,
    author: {
      userId: 'usr-cnt',
      displayName: 'Anna',
      shortTag: 'ANN2',
      color: '#34C759',
      role: 'contributor',
    },
  });
  repo.seedEntry({
    id: 'ent-1',
    mediaId: 'med-1',
    authorId: 'usr-own',
    text: 'Secret before retraction',
    markers: [{ id: 'mrk-1', entryId: 'ent-1', mediaId: 'med-1', number: 1, x: 0.5, y: 0.5 }],
    createdAt: '2026-11-18T12:04:00.000Z',
    serverReceivedAt: '2026-11-18T12:04:01.000Z',
    retractedAt: '2026-11-18T12:05:00.000Z',
    author: {
      userId: 'usr-own',
      displayName: 'Jan',
      shortTag: 'JAN1',
      color: '#007AFF',
      role: 'owner',
    },
  });
  repo.appendChange('apt-1', 'apartment', 'apt-1', 'created', now);
  repo.appendChange('apt-1', 'membership', 'usr-cnt', 'joined', '2026-11-18T12:01:00.000Z');
  repo.appendChange('apt-1', 'media', 'med-1', 'confirmed', '2026-11-18T12:03:00.000Z');
  repo.appendChange('apt-1', 'entry', 'ent-1', 'retracted', '2026-11-18T12:05:00.000Z');
  return repo;
}

describe('sync application use cases', () => {
  it('enforces access/query validation, paginates with exhaustCursorPages, and redacts payloads', async () => {
    const repo = setupRepo();
    const listFeed = createListApartmentChangesFeedUseCase({ syncRepository: repo });
    const listMine = createListMyApartmentsSyncUseCase({ syncRepository: repo });

    const missingApt = await listFeed.execute({ apartmentId: 'apt-missing', userId: 'usr-own' });
    expect(isErr(missingApt) && missingApt.error.code).toBe(
      SYNC_ERROR_CODES.SYNC_APARTMENT_NOT_FOUND,
    );

    const denied = await listFeed.execute({ apartmentId: 'apt-1', userId: 'usr-stranger' });
    expect(isErr(denied) && denied.error.code).toBe(SYNC_ERROR_CODES.SYNC_ACCESS_DENIED);

    const badAfter = await listFeed.execute({ apartmentId: 'apt-1', userId: 'usr-own', after: -1 });
    expect(isErr(badAfter) && badAfter.error.code).toBe(SYNC_ERROR_CODES.SYNC_VALIDATION_FAILED);

    const allChanges = await exhaustCursorPages(async (cursor) => {
      const page = await listFeed.execute({
        apartmentId: 'apt-1',
        userId: 'usr-cnt',
        after: cursor ?? 0,
        limit: 2,
      });
      if (!isOk(page)) throw new Error(page.error.message);
      return {
        items: page.value.changes,
        nextCursor: page.value.nextSeq,
        hasMore: page.value.hasMore,
      };
    }, 0);

    expect(allChanges.map((c) => c.seq)).toEqual([1, 2, 3, 4]);
    const aptChange = allChanges[0]?.payload;
    expect(aptChange?.kind).toBe('apartment');
    if (aptChange?.kind === 'apartment') {
      expect(aptChange.apartment.inviteCode).toBeNull();
      expect(aptChange.apartment.shouldSuggestInviteCodeReset).toBe(false);
    }

    const entryChange = allChanges[3]?.payload;
    expect(entryChange?.kind).toBe('entry');
    if (entryChange?.kind === 'entry') {
      expect(entryChange.entry.text).toBe('');
      expect(entryChange.entry.markers).toEqual([]);
      expect(entryChange.entry.retractedAt).not.toBeNull();
    }

    const ownerSummary = await listMine.execute('usr-own');
    expect(isOk(ownerSummary)).toBe(true);
    if (isOk(ownerSummary)) {
      expect(ownerSummary.value[0]).toMatchObject({
        role: 'owner',
        headSeq: 4,
        confirmedMediaCount: 1,
        latestMediaCapturedAt: '2026-11-18T12:02:00.000Z',
      });
      expect(ownerSummary.value[0]?.apartment.inviteCode).toBe('K7QM-4XPB');
      expect(ownerSummary.value[0]?.apartment.shouldSuggestInviteCodeReset).toBe(true);
    }
  });
});
