import { err, ok, type Clock, type DomainError, type Result } from '@stanmieszkania/shared';
import { confirmMediaUploaded, type Media } from '../domain/media.entity';
import {
  mediaAccessDeniedError,
  mediaAlreadyDeletedError,
  mediaAuthorRequiredError,
  mediaNotFoundError,
  mediaObjectNotUploadedError,
} from '../domain/media.errors';
import type { MediaRepository } from '../domain/media.repository';
import type { ObjectStoragePort } from '../domain/object-storage.port';

export interface ConfirmMediaUploadDeps {
  readonly mediaRepository: MediaRepository;
  readonly objectStorage: ObjectStoragePort;
  readonly clock: Clock;
}

export interface ConfirmMediaUploadCommand {
  readonly apartmentId: string;
  readonly mediaId: string;
  readonly userId: string;
}

export interface ConfirmMediaUploadUseCase {
  execute(input: ConfirmMediaUploadCommand): Promise<Result<Media, DomainError>>;
}

export function createConfirmMediaUploadUseCase(
  deps: ConfirmMediaUploadDeps,
): ConfirmMediaUploadUseCase {
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
      if (media.authorId !== input.userId) {
        return err(mediaAuthorRequiredError(input.mediaId));
      }
      if (media.deletedAt !== null) {
        return err(mediaAlreadyDeletedError(input.mediaId));
      }
      if (media.uploadStatus === 'uploaded') {
        return ok(media);
      }

      const head = await deps.objectStorage.headObject(media.r2Key);
      if (!head.ok) return head;
      if (head.value === null) {
        return err(mediaObjectNotUploadedError(media.id));
      }

      const sha = await deps.objectStorage.readObjectSha256(media.r2Key);
      if (!sha.ok) return sha;
      if (sha.value === null) {
        return err(mediaObjectNotUploadedError(media.id));
      }

      const serverReceivedAt = deps.clock.nowIso();
      const confirmed = confirmMediaUploaded(media, {
        uploadedSha256: sha.value,
        uploadedBytes: head.value.bytes,
        serverReceivedAt,
      });
      if (!confirmed.ok) {
        await deps.objectStorage.deleteObject(media.r2Key);
        return confirmed;
      }

      const persisted = await deps.mediaRepository.markUploaded({
        mediaId: media.id,
        apartmentId: media.apartmentId,
        serverReceivedAt,
      });
      if (!persisted.ok) return persisted;

      return ok(confirmed.value);
    },
  };
}
