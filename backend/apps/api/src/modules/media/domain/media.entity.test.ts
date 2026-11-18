import { isErr, isOk } from '@stanmieszkania/shared';
import { describe, expect, it } from 'vitest';
import {
  buildMediaR2Key,
  confirmMediaUploaded,
  createPendingMedia,
  isMediaVerified,
  softDeleteMedia,
} from './media.entity';
import { MEDIA_ERROR_CODES } from './media.errors';

const VALID_SHA = 'a'.repeat(64);
const BASE_INPUT = {
  id: 'med-1',
  apartmentId: 'apt-1',
  authorId: 'usr-1',
  kind: 'photo' as const,
  source: 'camera' as const,
  sha256: VALID_SHA.toUpperCase(),
  capturedAt: '2026-11-18T12:00:00.000Z',
  capturedTz: 'Europe/Warsaw',
  capturedAtFromImport: false,
  location: { lat: 52.2297, lng: 21.0122, accuracyM: 12.5, locationSource: 'device' as const },
  width: 1600,
  height: 1200,
  bytes: 150_000,
  maxBytes: 3_145_728,
};

describe('media.entity', () => {
  it('creates pending photo with canonical r2Key and rejects video & invalid fields', () => {
    const video = createPendingMedia({ ...BASE_INPUT, kind: 'video' });
    expect(isErr(video) && video.error.code).toBe(MEDIA_ERROR_CODES.VIDEO_DISABLED_IN_MVP);

    const oversized = createPendingMedia({ ...BASE_INPUT, bytes: 4_000_000 });
    expect(isErr(oversized) && oversized.error.code).toBe(
      MEDIA_ERROR_CODES.MEDIA_VALIDATION_FAILED,
    );

    const badLat = createPendingMedia({
      ...BASE_INPUT,
      location: { lat: 95, lng: 21, accuracyM: 5, locationSource: 'exif' },
    });
    expect(isErr(badLat) && badLat.error.code).toBe(MEDIA_ERROR_CODES.MEDIA_VALIDATION_FAILED);

    const badAccuracy = createPendingMedia({
      ...BASE_INPUT,
      location: { lat: 52, lng: 21, accuracyM: 0, locationSource: 'device' },
    });
    expect(isErr(badAccuracy) && badAccuracy.error.code).toBe(
      MEDIA_ERROR_CODES.MEDIA_VALIDATION_FAILED,
    );

    const built = createPendingMedia(BASE_INPUT);
    expect(isOk(built)).toBe(true);
    if (isOk(built)) {
      expect(built.value.sha256).toBe(VALID_SHA);
      expect(built.value.r2Key).toBe(buildMediaR2Key('apt-1', 'med-1'));
      expect(built.value.uploadStatus).toBe('pending');
      expect(built.value.serverReceivedAt).toBeNull();
      expect(isMediaVerified(built.value)).toBe(false);
    }
  });

  it('confirms upload idempotently on hash/bytes match and rejects mismatches', () => {
    const built = createPendingMedia(BASE_INPUT);
    expect(isOk(built)).toBe(true);
    if (!isOk(built)) return;

    const wrongSha = confirmMediaUploaded(built.value, {
      uploadedSha256: 'b'.repeat(64),
      uploadedBytes: 150_000,
      serverReceivedAt: '2026-11-18T12:01:00.000Z',
    });
    expect(isErr(wrongSha) && wrongSha.error.code).toBe(MEDIA_ERROR_CODES.MEDIA_HASH_MISMATCH);

    const wrongBytes = confirmMediaUploaded(built.value, {
      uploadedSha256: VALID_SHA,
      uploadedBytes: 149_999,
      serverReceivedAt: '2026-11-18T12:01:00.000Z',
    });
    expect(isErr(wrongBytes) && wrongBytes.error.code).toBe(MEDIA_ERROR_CODES.MEDIA_HASH_MISMATCH);

    const confirmed = confirmMediaUploaded(built.value, {
      uploadedSha256: VALID_SHA.toUpperCase(),
      uploadedBytes: 150_000,
      serverReceivedAt: '2026-11-18T12:01:00.000Z',
    });
    expect(isOk(confirmed)).toBe(true);
    if (!isOk(confirmed)) return;
    expect(confirmed.value.uploadStatus).toBe('uploaded');
    expect(isMediaVerified(confirmed.value)).toBe(true);

    const replay = confirmMediaUploaded(confirmed.value, {
      uploadedSha256: VALID_SHA,
      uploadedBytes: 150_000,
      serverReceivedAt: '2026-11-18T12:05:00.000Z',
    });
    expect(isOk(replay) && replay.value).toEqual(confirmed.value);
  });

  it('enforces author-only soft delete, preserves hashes/timestamps, and blocks post-delete confirm', () => {
    const built = createPendingMedia(BASE_INPUT);
    expect(isOk(built)).toBe(true);
    if (!isOk(built)) return;

    const confirmed = confirmMediaUploaded(built.value, {
      uploadedSha256: VALID_SHA,
      uploadedBytes: 150_000,
      serverReceivedAt: '2026-11-18T12:01:00.000Z',
    });
    if (!isOk(confirmed)) return;

    const foreignDelete = softDeleteMedia(confirmed.value, {
      actorUserId: 'usr-other',
      nowIso: '2026-11-18T12:02:00.000Z',
    });
    expect(isErr(foreignDelete) && foreignDelete.error.code).toBe(
      MEDIA_ERROR_CODES.MEDIA_AUTHOR_REQUIRED,
    );

    const deleted = softDeleteMedia(confirmed.value, {
      actorUserId: 'usr-1',
      nowIso: '2026-11-18T12:02:00.000Z',
    });
    expect(isOk(deleted)).toBe(true);
    if (!isOk(deleted)) return;
    expect(deleted.value.deletedAt).toBe('2026-11-18T12:02:00.000Z');
    expect(deleted.value.deletedBy).toBe('usr-1');
    expect(deleted.value.sha256).toBe(VALID_SHA);
    expect(deleted.value.serverReceivedAt).toBe('2026-11-18T12:01:00.000Z');

    const replayDelete = softDeleteMedia(deleted.value, {
      actorUserId: 'usr-1',
      nowIso: '2026-11-18T12:09:00.000Z',
    });
    expect(isOk(replayDelete) && replayDelete.value).toEqual(deleted.value);

    const confirmAfterDelete = confirmMediaUploaded(deleted.value, {
      uploadedSha256: VALID_SHA,
      uploadedBytes: 150_000,
      serverReceivedAt: '2026-11-18T12:10:00.000Z',
    });
    expect(isErr(confirmAfterDelete) && confirmAfterDelete.error.code).toBe(
      MEDIA_ERROR_CODES.MEDIA_ALREADY_DELETED,
    );
  });
});
