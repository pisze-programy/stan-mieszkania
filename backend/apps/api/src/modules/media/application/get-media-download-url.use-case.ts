import { err, type DomainError, type Result } from '@stanmieszkania/shared';
import { isMediaVerified } from '../domain/media.entity';
import {
  mediaAccessDeniedError,
  mediaAlreadyDeletedError,
  mediaNotFoundError,
  mediaObjectNotUploadedError,
} from '../domain/media.errors';
import type { MediaRepository } from '../domain/media.repository';
import type { ObjectStoragePort, PresignedUrl } from '../domain/object-storage.port';

export interface GetMediaDownloadUrlDeps {
  readonly mediaRepository: MediaRepository;
  readonly objectStorage: ObjectStoragePort;
  readonly presignGetTtlMs: number;
}

export interface GetMediaDownloadUrlQuery {
  readonly apartmentId: string;
  readonly mediaId: string;
  readonly userId: string;
}

export interface GetMediaDownloadUrlUseCase {
  execute(input: GetMediaDownloadUrlQuery): Promise<Result<PresignedUrl, DomainError>>;
}

export function createGetMediaDownloadUrlUseCase(
  deps: GetMediaDownloadUrlDeps,
): GetMediaDownloadUrlUseCase {
  return {
    execute: async (input) => {
      const access = await deps.mediaRepository.findApartmentAccess(
        input.apartmentId,
        input.userId,
      );
      if (!access.ok) return access;
      if (access.value === null) return err(mediaNotFoundError(input.mediaId));
      if (!access.value.isActiveMember) return err(mediaAccessDeniedError(input.apartmentId));

      const found = await deps.mediaRepository.findById(input.mediaId);
      if (!found.ok) return found;
      const media = found.value;
      if (media === null || media.apartmentId !== input.apartmentId) {
        return err(mediaNotFoundError(input.mediaId));
      }
      if (media.deletedAt !== null) {
        return err(mediaAlreadyDeletedError(media.id));
      }
      if (!isMediaVerified(media)) {
        return err(mediaObjectNotUploadedError(media.id));
      }

      return deps.objectStorage.createPresignedGetUrl({
        r2Key: media.r2Key,
        expiresInMs: deps.presignGetTtlMs,
      });
    },
  };
}
