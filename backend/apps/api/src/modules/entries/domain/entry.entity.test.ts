import { isErr, isOk } from '@stanmieszkania/shared';
import { describe, expect, it } from 'vitest';
import { ENTRY_TEXT_MAX_LENGTH, REDACTED_ENTRY_TEXT } from './entries.constants';
import { ENTRY_ERROR_CODES } from './entries.errors';
import {
  canAttachEntryToMedia,
  createVerifiedEntry,
  isEntryRetracted,
  isEntryVerified,
  retractEntry,
} from './entry.entity';

describe('Entry entity and lifecycle policies', () => {
  it('creates a verified entry with trimmed text, renumbered markers, and serverReceivedAt', () => {
    const created = createVerifiedEntry({
      id: 'entry-1',
      mediaId: 'media-1',
      authorId: 'user-1',
      text: '  Crack on tile [1] and wall [2]  ',
      draftMarkers: [
        { id: 'mk-1', localNumber: 1, x: 0.15, y: 0.25 },
        { id: 'mk-2', localNumber: 2, x: 0.85, y: 0.75 },
      ],
      currentMaxMarkerNumber: 3,
      createdAt: '2026-11-18T10:00:00.000Z',
      serverReceivedAt: '2026-11-18T10:00:05.000Z',
    });

    expect(isOk(created)).toBe(true);
    if (isOk(created)) {
      expect(created.value.entry.text).toBe('Crack on tile [4] and wall [5]');
      expect(created.value.entry.markers.map((marker) => marker.number)).toEqual([4, 5]);
      expect(created.value.entry.serverReceivedAt).toBe('2026-11-18T10:00:05.000Z');
      expect(created.value.entry.retractedAt).toBeNull();
      expect(isEntryVerified(created.value.entry)).toBe(true);
      expect(isEntryRetracted(created.value.entry)).toBe(false);
    }
  });

  it('validates entry text length boundaries (1..4000)', () => {
    const empty = createVerifiedEntry({
      id: 'entry-empty',
      mediaId: 'media-1',
      authorId: 'user-1',
      text: '   \n\t  ',
      draftMarkers: [],
      currentMaxMarkerNumber: 0,
      createdAt: '2026-11-18T10:00:00.000Z',
      serverReceivedAt: '2026-11-18T10:00:01.000Z',
    });
    expect(isErr(empty)).toBe(true);
    if (isErr(empty)) {
      expect(empty.error.code).toBe(ENTRY_ERROR_CODES.ENTRY_VALIDATION_FAILED);
    }

    const tooLong = createVerifiedEntry({
      id: 'entry-long',
      mediaId: 'media-1',
      authorId: 'user-1',
      text: 'x'.repeat(ENTRY_TEXT_MAX_LENGTH + 1),
      draftMarkers: [],
      currentMaxMarkerNumber: 0,
      createdAt: '2026-11-18T10:00:00.000Z',
      serverReceivedAt: '2026-11-18T10:00:01.000Z',
    });
    expect(isErr(tooLong)).toBe(true);
    if (isErr(tooLong)) {
      expect(tooLong.error.code).toBe(ENTRY_ERROR_CODES.ENTRY_VALIDATION_FAILED);
    }

    const exactMax = createVerifiedEntry({
      id: 'entry-max',
      mediaId: 'media-1',
      authorId: 'user-1',
      text: 'x'.repeat(ENTRY_TEXT_MAX_LENGTH),
      draftMarkers: [],
      currentMaxMarkerNumber: 0,
      createdAt: '2026-11-18T10:00:00.000Z',
      serverReceivedAt: '2026-11-18T10:00:01.000Z',
    });
    expect(isOk(exactMax)).toBe(true);
  });

  it('enforces author-only retraction, redacts text, preserves metadata/markers, and rejects double retract', () => {
    const created = createVerifiedEntry({
      id: 'entry-1',
      mediaId: 'media-1',
      authorId: 'author-1',
      text: 'Sensitive note [1]',
      draftMarkers: [{ id: 'mk-1', localNumber: 1, x: 0.5, y: 0.5 }],
      currentMaxMarkerNumber: 0,
      createdAt: '2026-11-18T10:00:00.000Z',
      serverReceivedAt: '2026-11-18T10:00:02.000Z',
    });
    expect(isOk(created)).toBe(true);
    if (!isOk(created)) {
      return;
    }

    const wrongActor = retractEntry(created.value.entry, {
      actorUserId: 'other-user',
      nowIso: '2026-11-18T10:05:00.000Z',
    });
    expect(isErr(wrongActor)).toBe(true);
    if (isErr(wrongActor)) {
      expect(wrongActor.error.code).toBe(ENTRY_ERROR_CODES.ENTRY_AUTHOR_REQUIRED);
    }

    const retracted = retractEntry(created.value.entry, {
      actorUserId: 'author-1',
      nowIso: '2026-11-18T10:05:00.000Z',
    });
    expect(isOk(retracted)).toBe(true);
    if (!isOk(retracted)) {
      return;
    }

    expect(retracted.value.text).toBe(REDACTED_ENTRY_TEXT);
    expect(retracted.value.retractedAt).toBe('2026-11-18T10:05:00.000Z');
    expect(retracted.value.authorId).toBe('author-1');
    expect(retracted.value.createdAt).toBe('2026-11-18T10:00:00.000Z');
    expect(retracted.value.serverReceivedAt).toBe('2026-11-18T10:00:02.000Z');
    expect(retracted.value.markers).toEqual(created.value.entry.markers);
    expect(isEntryRetracted(retracted.value)).toBe(true);

    const repeatRetract = retractEntry(retracted.value, {
      actorUserId: 'author-1',
      nowIso: '2026-11-18T10:06:00.000Z',
    });
    expect(isErr(repeatRetract)).toBe(true);
    if (isErr(repeatRetract)) {
      expect(repeatRetract.error.code).toBe(ENTRY_ERROR_CODES.ENTRY_ALREADY_RETRACTED);
    }
  });

  it('enforces Invariant 7 media readiness rules for attaching cloud entries', () => {
    expect(
      isOk(
        canAttachEntryToMedia(
          { mediaId: 'm-1', authorId: 'u-1', uploadStatus: 'uploaded', deletedAt: null },
          'u-2',
        ),
      ),
    ).toBe(true);

    expect(
      isOk(
        canAttachEntryToMedia(
          { mediaId: 'm-1', authorId: 'u-1', uploadStatus: 'pending', deletedAt: null },
          'u-1',
        ),
      ),
    ).toBe(true);

    const otherUserPending = canAttachEntryToMedia(
      { mediaId: 'm-1', authorId: 'u-1', uploadStatus: 'pending', deletedAt: null },
      'u-2',
    );
    expect(isErr(otherUserPending)).toBe(true);
    if (isErr(otherUserPending)) {
      expect(otherUserPending.error.code).toBe(ENTRY_ERROR_CODES.ENTRY_MEDIA_NOT_READY);
    }

    const deletedMedia = canAttachEntryToMedia(
      {
        mediaId: 'm-1',
        authorId: 'u-1',
        uploadStatus: 'uploaded',
        deletedAt: '2026-11-18T11:00:00.000Z',
      },
      'u-1',
    );
    expect(isErr(deletedMedia)).toBe(true);
    if (isErr(deletedMedia)) {
      expect(deletedMedia.error.code).toBe(ENTRY_ERROR_CODES.ENTRY_MEDIA_NOT_READY);
    }
  });
});
