import { isErr, isOk } from '@stanmieszkania/shared';
import { FixedClock } from '@stanmieszkania/testing';
import { describe, expect, it } from 'vitest';
import { buildMediaR2Key } from '../domain/media.entity';
import { MEDIA_ERROR_CODES } from '../domain/media.errors';
import { InMemoryMediaRepository, InMemoryObjectStorage } from '../testing/in-memory-media.doubles';
import { createConfirmMediaUploadUseCase } from './confirm-media-upload.use-case';
import { createGetMediaDownloadUrlUseCase } from './get-media-download-url.use-case';
import { createGetMediaUseCase } from './get-media.use-case';
import { createInitMediaUploadUseCase } from './init-media-upload.use-case';
import { createListApartmentMediaUseCase } from './list-apartment-media.use-case';
import { createSoftDeleteMediaUseCase } from './soft-delete-media.use-case';

const VALID_SHA = 'a'.repeat(64);
const OTHER_SHA = 'b'.repeat(64);
const BASE_INIT = {
  apartmentId: 'apt-1',
  mediaId: 'med-1',
  userId: 'usr-1',
  kind: 'photo' as const,
  source: 'camera' as const,
  sha256: VALID_SHA,
  capturedAt: '2026-11-18T12:00:00.000Z',
  capturedTz: 'Europe/Warsaw',
  capturedAtFromImport: false,
  width: 1200,
  height: 800,
  bytes: 100_000,
};

function setupDeps(quota = 250) {
  const mediaRepository = new InMemoryMediaRepository();
  const objectStorage = new InMemoryObjectStorage();
  const clock = new FixedClock();
  mediaRepository.seedApartment('apt-1', 0);
  mediaRepository.seedMember('apt-1', {
    userId: 'usr-1',
    displayName: 'Jan',
    shortTag: 'JAN1',
    color: '#007AFF',
    role: 'owner',
  });
  mediaRepository.seedMember('apt-1', {
    userId: 'usr-2',
    displayName: 'Anna',
    shortTag: 'ANN2',
    color: '#34C759',
    role: 'contributor',
  });
  return {
    mediaRepository,
    objectStorage,
    init: createInitMediaUploadUseCase({
      mediaRepository,
      objectStorage,
      clock,
      cloudMediaQuota: quota,
      maxBytes: 3_145_728,
      presignPutTtlMs: 900_000,
    }),
    confirm: createConfirmMediaUploadUseCase({ mediaRepository, objectStorage, clock }),
    getMedia: createGetMediaUseCase({ mediaRepository }),
    listMedia: createListApartmentMediaUseCase({ mediaRepository }),
    getUrl: createGetMediaDownloadUrlUseCase({
      mediaRepository,
      objectStorage,
      presignGetTtlMs: 3_600_000,
    }),
    softDelete: createSoftDeleteMediaUseCase({ mediaRepository, clock }),
  };
}

describe('media application use cases', () => {
  it('supports idempotent init, video/GPS/conflict/quota checks, pending isolation, and corrupt R2 cleanup on confirm', async () => {
    const { mediaRepository, objectStorage, init, confirm, getUrl, getMedia, listMedia } =
      setupDeps(1);

    const video = await init.execute({ ...BASE_INIT, mediaId: 'med-vid', kind: 'video' });
    expect(isErr(video) && video.error.code).toBe(MEDIA_ERROR_CODES.VIDEO_DISABLED_IN_MVP);

    const partialGps = await init.execute({ ...BASE_INIT, lat: 52.2 });
    expect(isErr(partialGps) && partialGps.error.code).toBe(
      MEDIA_ERROR_CODES.MEDIA_VALIDATION_FAILED,
    );

    const firstInit = await init.execute({
      ...BASE_INIT,
      lat: 52.23,
      lng: 21.01,
      accuracyM: 8,
      locationSource: 'device',
    });
    expect(isOk(firstInit)).toBe(true);
    expect(mediaRepository.getCloudMediaCount('apt-1')).toBe(1);

    const retryInit = await init.execute(BASE_INIT);
    expect(isOk(retryInit) && retryInit.value.upload !== null).toBe(true);
    expect(mediaRepository.getCloudMediaCount('apt-1')).toBe(1);

    const conflictInit = await init.execute({ ...BASE_INIT, sha256: OTHER_SHA });
    expect(isErr(conflictInit) && conflictInit.error.code).toBe(MEDIA_ERROR_CODES.MEDIA_CONFLICT);

    const quotaExceeded = await init.execute({
      ...BASE_INIT,
      mediaId: 'med-2',
      userId: 'usr-2',
      source: 'import',
      sha256: OTHER_SHA,
      capturedAtFromImport: true,
    });
    expect(isErr(quotaExceeded) && quotaExceeded.error.code).toBe(MEDIA_ERROR_CODES.QUOTA_EXCEEDED);

    const pendingUrl = await getUrl.execute({
      apartmentId: 'apt-1',
      mediaId: 'med-1',
      userId: 'usr-2',
    });
    expect(isErr(pendingUrl) && pendingUrl.error.code).toBe(
      MEDIA_ERROR_CODES.MEDIA_OBJECT_NOT_UPLOADED,
    );

    const hiddenGet = await getMedia.execute({
      apartmentId: 'apt-1',
      mediaId: 'med-1',
      userId: 'usr-2',
    });
    expect(isErr(hiddenGet) && hiddenGet.error.code).toBe(MEDIA_ERROR_CODES.MEDIA_NOT_FOUND);
    const hiddenList = await listMedia.execute({ apartmentId: 'apt-1', userId: 'usr-2' });
    expect(isOk(hiddenList) && hiddenList.value.items).toHaveLength(0);
    const authorList = await listMedia.execute({ apartmentId: 'apt-1', userId: 'usr-1' });
    expect(isOk(authorList) && authorList.value.items).toHaveLength(1);

    const r2Key = buildMediaR2Key('apt-1', 'med-1');
    objectStorage.seedObject(r2Key, 100_000, OTHER_SHA);
    const mismatch = await confirm.execute({
      apartmentId: 'apt-1',
      mediaId: 'med-1',
      userId: 'usr-1',
    });
    expect(isErr(mismatch) && mismatch.error.code).toBe(MEDIA_ERROR_CODES.MEDIA_HASH_MISMATCH);
    expect(objectStorage.objects.has(r2Key)).toBe(false);

    objectStorage.seedObject(r2Key, 100_000, VALID_SHA);
    const confirmed = await confirm.execute({
      apartmentId: 'apt-1',
      mediaId: 'med-1',
      userId: 'usr-1',
    });
    expect(isOk(confirmed) && confirmed.value.uploadStatus).toBe('uploaded');
  });

  it('enforces author-only soft delete and preserves quota count', async () => {
    const { mediaRepository, objectStorage, init, confirm, softDelete, getUrl } = setupDeps(10);
    await init.execute(BASE_INIT);
    objectStorage.seedObject(buildMediaR2Key('apt-1', 'med-1'), 100_000, VALID_SHA);
    await confirm.execute({ apartmentId: 'apt-1', mediaId: 'med-1', userId: 'usr-1' });

    const foreignDelete = await softDelete.execute({
      apartmentId: 'apt-1',
      mediaId: 'med-1',
      userId: 'usr-2',
    });
    expect(isErr(foreignDelete) && foreignDelete.error.code).toBe(
      MEDIA_ERROR_CODES.MEDIA_AUTHOR_REQUIRED,
    );

    const deleted = await softDelete.execute({
      apartmentId: 'apt-1',
      mediaId: 'med-1',
      userId: 'usr-1',
    });
    expect(isOk(deleted) && deleted.value.deletedAt !== null).toBe(true);
    expect(mediaRepository.getCloudMediaCount('apt-1')).toBe(1);

    const urlAfterDelete = await getUrl.execute({
      apartmentId: 'apt-1',
      mediaId: 'med-1',
      userId: 'usr-2',
    });
    expect(isErr(urlAfterDelete) && urlAfterDelete.error.code).toBe(
      MEDIA_ERROR_CODES.MEDIA_ALREADY_DELETED,
    );
  });
});
