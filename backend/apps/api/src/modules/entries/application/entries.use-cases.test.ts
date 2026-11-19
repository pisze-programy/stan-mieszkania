import { isErr, isOk } from '@stanmieszkania/shared';
import { FixedClock } from '@stanmieszkania/testing';
import { describe, expect, it } from 'vitest';
import { ENTRY_ERROR_CODES } from '../domain/entries.errors';
import { InMemoryEntryRepository } from '../testing/in-memory-entry.repository';
import { createCreateEntryUseCase } from './create-entry.use-case';
import { createListMediaEntriesUseCase } from './list-media-entries.use-case';
import { createRetractEntryUseCase } from './retract-entry.use-case';

describe('Entries application use cases', () => {
  function setup() {
    const repo = new InMemoryEntryRepository();
    repo.seedApartment('apt-1', ['owner-1', 'contrib-1']);
    repo.seedAuthor({
      userId: 'owner-1',
      displayName: 'Anna',
      shortTag: 'ANNA',
      color: '#3B82F6',
      role: 'owner',
    });
    repo.seedAuthor({
      userId: 'contrib-1',
      displayName: 'Piotr',
      shortTag: 'PIOT',
      color: '#10B981',
      role: 'contributor',
    });
    repo.seedMedia({
      mediaId: 'm-uploaded',
      apartmentId: 'apt-1',
      authorId: 'owner-1',
      uploadStatus: 'uploaded',
      deletedAt: null,
    });
    repo.seedMedia({
      mediaId: 'm-pending',
      apartmentId: 'apt-1',
      authorId: 'owner-1',
      uploadStatus: 'pending',
      deletedAt: null,
    });
    const clock = new FixedClock('2026-11-18T14:00:00.000Z');
    return {
      repo,
      clock,
      createEntry: createCreateEntryUseCase({ entryRepository: repo, clock }),
      retractEntry: createRetractEntryUseCase({ entryRepository: repo, clock }),
      listEntries: createListMediaEntriesUseCase({ entryRepository: repo }),
    };
  }

  it('numbers markers monotonically across authors, replays idempotently, and rejects entryId conflicts', async () => {
    const { createEntry, listEntries, clock } = setup();

    const first = await createEntry.execute({
      apartmentId: 'apt-1',
      mediaId: 'm-uploaded',
      entryId: 'e-1',
      actorUserId: 'owner-1',
      text: 'Scratch [1] and dent [2]',
      draftMarkers: [
        { id: 'mk-1', localNumber: 1, x: 0.1, y: 0.2 },
        { id: 'mk-2', localNumber: 2, x: 0.8, y: 0.9 },
      ],
      createdAt: '2026-11-18T13:59:00.000Z',
    });
    expect(isOk(first)).toBe(true);

    clock.advanceBy(1_000);
    const second = await createEntry.execute({
      apartmentId: 'apt-1',
      mediaId: 'm-uploaded',
      entryId: 'e-2',
      actorUserId: 'contrib-1',
      text: 'Added stain [1]',
      draftMarkers: [{ id: 'mk-3', localNumber: 1, x: 0.4, y: 0.5 }],
      createdAt: '2026-11-18T14:00:00.000Z',
    });
    expect(isOk(second)).toBe(true);
    if (isOk(second)) {
      expect(second.value.entry.text).toBe('Added stain [3]');
      expect(second.value.entry.markers.map((m) => m.number)).toEqual([3]);
    }

    const replay = await createEntry.execute({
      apartmentId: 'apt-1',
      mediaId: 'm-uploaded',
      entryId: 'e-2',
      actorUserId: 'contrib-1',
      text: 'Added stain [1]',
      draftMarkers: [{ id: 'mk-3', localNumber: 1, x: 0.4, y: 0.5 }],
      createdAt: '2026-11-18T14:00:00.000Z',
    });
    expect(replay).toEqual(second);

    const conflict = await createEntry.execute({
      apartmentId: 'apt-1',
      mediaId: 'm-uploaded',
      entryId: 'e-2',
      actorUserId: 'owner-1',
      text: 'Hijack',
      draftMarkers: [],
      createdAt: '2026-11-18T14:01:00.000Z',
    });
    expect(isErr(conflict)).toBe(true);
    if (isErr(conflict)) {
      expect(conflict.error.code).toBe(ENTRY_ERROR_CODES.ENTRY_CONFLICT);
    }

    const timeline = await listEntries.execute({
      apartmentId: 'apt-1',
      mediaId: 'm-uploaded',
      actorUserId: 'owner-1',
    });
    expect(isOk(timeline)).toBe(true);
    if (isOk(timeline)) {
      expect(timeline.value.map((item) => item.entry.id)).toEqual(['e-1', 'e-2']);
    }
  });

  it('enforces membership, Invariant 7 pending-media ownership, and idempotent author-only retraction', async () => {
    const { createEntry, retractEntry, clock } = setup();

    const outsider = await createEntry.execute({
      apartmentId: 'apt-1',
      mediaId: 'm-uploaded',
      entryId: 'e-outsider',
      actorUserId: 'stranger',
      text: 'Hello',
      draftMarkers: [],
      createdAt: '2026-11-18T14:00:00.000Z',
    });
    expect(isErr(outsider) && outsider.error.code).toBe(ENTRY_ERROR_CODES.ENTRY_ACCESS_DENIED);

    const contribOnPending = await createEntry.execute({
      apartmentId: 'apt-1',
      mediaId: 'm-pending',
      entryId: 'e-pending-bad',
      actorUserId: 'contrib-1',
      text: 'Not ready',
      draftMarkers: [],
      createdAt: '2026-11-18T14:00:00.000Z',
    });
    expect(isErr(contribOnPending) && contribOnPending.error.code).toBe(
      ENTRY_ERROR_CODES.ENTRY_MEDIA_NOT_READY,
    );

    const ownerOnPending = await createEntry.execute({
      apartmentId: 'apt-1',
      mediaId: 'm-pending',
      entryId: 'e-pending-ok',
      actorUserId: 'owner-1',
      text: 'Own summary [1]',
      draftMarkers: [{ id: 'mk-p1', localNumber: 1, x: 0.5, y: 0.5 }],
      createdAt: '2026-11-18T14:00:00.000Z',
    });
    expect(isOk(ownerOnPending)).toBe(true);

    const wrongRetract = await retractEntry.execute({
      apartmentId: 'apt-1',
      mediaId: 'm-pending',
      entryId: 'e-pending-ok',
      actorUserId: 'contrib-1',
    });
    expect(isErr(wrongRetract) && wrongRetract.error.code).toBe(
      ENTRY_ERROR_CODES.ENTRY_AUTHOR_REQUIRED,
    );

    clock.advanceBy(10_000);
    const retracted = await retractEntry.execute({
      apartmentId: 'apt-1',
      mediaId: 'm-pending',
      entryId: 'e-pending-ok',
      actorUserId: 'owner-1',
    });
    expect(isOk(retracted)).toBe(true);
    if (isOk(retracted)) {
      expect(retracted.value.entry.text).toBe('');
      expect(retracted.value.entry.markers).toEqual([]);
      expect(retracted.value.entry.retractedAt).toBe(clock.nowIso());
    }

    const repeat = await retractEntry.execute({
      apartmentId: 'apt-1',
      mediaId: 'm-pending',
      entryId: 'e-pending-ok',
      actorUserId: 'owner-1',
    });
    expect(repeat).toEqual(retracted);
  });
});
