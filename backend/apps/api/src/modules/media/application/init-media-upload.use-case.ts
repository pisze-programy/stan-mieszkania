import { err, ok, type Clock, type DomainError, type Result } from '@stanmieszkania/shared';
import { MEDIA_CONTENT_TYPE_JPEG } from '../domain/media.constants';
import {
  createPendingMedia,
  type LocationSource,
  type Media,
  type MediaKind,
  type MediaLocation,
  type MediaSource,
} from '../domain/media.entity';
import {
  mediaAccessDeniedError,
  mediaAlreadyDeletedError,
  mediaConflictError,
  mediaNotFoundError,
  mediaValidationFailedError,
} from '../domain/media.errors';
import { canReserveCloudMediaSlot } from '../domain/media-quota.policy';
import type { MediaRepository } from '../domain/media.repository';
import type { ObjectStoragePort, PresignedUrl } from '../domain/object-storage.port';

export interface InitMediaUploadDeps {
  readonly mediaRepository: MediaRepository;
  readonly objectStorage: ObjectStoragePort;
  readonly clock: Clock;
  readonly cloudMediaQuota: number;
  readonly maxBytes: number;
  readonly presignPutTtlMs: number;
}

export interface InitMediaUploadCommand {
  readonly apartmentId: string;
  readonly mediaId: string;
  readonly userId: string;
  readonly kind: MediaKind;
  readonly source: MediaSource;
  readonly sha256: string;
  readonly capturedAt: string;
  readonly capturedTz: string;
  readonly capturedAtFromImport: boolean;
  readonly width: number;
  readonly height: number;
  readonly bytes: number;
  readonly lat?: number;
  readonly lng?: number;
  readonly accuracyM?: number;
  readonly locationSource?: LocationSource;
}

export interface InitMediaUploadResult {
  readonly media: Media;
  readonly upload: PresignedUrl | null;
}

export interface InitMediaUploadUseCase {
  execute(input: InitMediaUploadCommand): Promise<Result<InitMediaUploadResult, DomainError>>;
}

function buildOptionalLocation(
  input: InitMediaUploadCommand,
): Result<MediaLocation | null, DomainError> {
  if (input.lat === undefined && input.lng === undefined) {
    if (input.accuracyM !== undefined || input.locationSource !== undefined) {
      return err(
        mediaValidationFailedError('accuracyM and locationSource require both lat and lng'),
      );
    }
    return ok(null);
  }
  if (input.lat === undefined || input.lng === undefined) {
    return err(mediaValidationFailedError('Both lat and lng must be provided together'));
  }
  return ok({
    lat: input.lat,
    lng: input.lng,
    accuracyM: input.accuracyM ?? null,
    locationSource: input.locationSource ?? null,
  });
}

async function resolveExistingInit(
  existing: Media,
  expectedApartmentId: string,
  expectedUserId: string,
  expectedSha256: string,
  objectStorage: ObjectStoragePort,
  presignPutTtlMs: number,
): Promise<Result<InitMediaUploadResult, DomainError>> {
  if (
    existing.apartmentId !== expectedApartmentId ||
    existing.authorId !== expectedUserId ||
    existing.sha256 !== expectedSha256
  ) {
    return err(
      mediaConflictError('Media ID already exists with conflicting apartment, author, or sha256', {
        mediaId: existing.id,
      }),
    );
  }
  if (existing.deletedAt !== null) {
    return err(mediaAlreadyDeletedError(existing.id));
  }
  if (existing.uploadStatus === 'uploaded') {
    return ok({ media: existing, upload: null });
  }
  const putUrl = await objectStorage.createPresignedPutUrl({
    r2Key: existing.r2Key,
    contentType: MEDIA_CONTENT_TYPE_JPEG,
    bytes: existing.bytes,
    sha256: existing.sha256,
    expiresInMs: presignPutTtlMs,
  });
  if (!putUrl.ok) {
    return putUrl;
  }
  return ok({ media: existing, upload: putUrl.value });
}

export function createInitMediaUploadUseCase(deps: InitMediaUploadDeps): InitMediaUploadUseCase {
  return {
    execute: async (input) => {
      const access = await deps.mediaRepository.findApartmentAccess(
        input.apartmentId,
        input.userId,
      );
      if (!access.ok) return access;
      if (access.value === null) return err(mediaNotFoundError(input.mediaId));
      if (!access.value.isActiveMember) return err(mediaAccessDeniedError(input.apartmentId));

      const location = buildOptionalLocation(input);
      if (!location.ok) return location;

      const built = createPendingMedia({
        id: input.mediaId,
        apartmentId: input.apartmentId,
        authorId: input.userId,
        kind: input.kind,
        source: input.source,
        sha256: input.sha256,
        capturedAt: input.capturedAt,
        capturedTz: input.capturedTz,
        capturedAtFromImport: input.capturedAtFromImport,
        location: location.value,
        width: input.width,
        height: input.height,
        bytes: input.bytes,
        maxBytes: deps.maxBytes,
      });
      if (!built.ok) return built;

      const existing = await deps.mediaRepository.findById(input.mediaId);
      if (!existing.ok) return existing;
      if (existing.value !== null) {
        return resolveExistingInit(
          existing.value,
          input.apartmentId,
          input.userId,
          built.value.sha256,
          deps.objectStorage,
          deps.presignPutTtlMs,
        );
      }

      const quotaCheck = canReserveCloudMediaSlot(
        access.value.cloudMediaCount,
        deps.cloudMediaQuota,
      );
      if (!quotaCheck.ok) return quotaCheck;

      const reserved = await deps.mediaRepository.reservePendingSlot({
        media: built.value,
        quota: deps.cloudMediaQuota,
        createdAt: deps.clock.nowIso(),
      });
      if (!reserved.ok) {
        const raceCheck = await deps.mediaRepository.findById(input.mediaId);
        if (raceCheck.ok && raceCheck.value !== null) {
          return resolveExistingInit(
            raceCheck.value,
            input.apartmentId,
            input.userId,
            built.value.sha256,
            deps.objectStorage,
            deps.presignPutTtlMs,
          );
        }
        return reserved;
      }

      const putUrl = await deps.objectStorage.createPresignedPutUrl({
        r2Key: built.value.r2Key,
        contentType: MEDIA_CONTENT_TYPE_JPEG,
        bytes: built.value.bytes,
        sha256: built.value.sha256,
        expiresInMs: deps.presignPutTtlMs,
      });
      if (!putUrl.ok) return putUrl;

      return ok({ media: built.value, upload: putUrl.value });
    },
  };
}
