import { err, ok, type DomainError, type Result } from '@stanmieszkania/shared';
import { mediaAccessDeniedError, mediaNotFoundError } from '../domain/media.errors';
import type { MediaRepository, MediaWithAuthor } from '../domain/media.repository';

export interface GetMediaDeps {
  readonly mediaRepository: MediaRepository;
}

export interface GetMediaQuery {
  readonly apartmentId: string;
  readonly mediaId: string;
  readonly userId: string;
}

export interface GetMediaUseCase {
  execute(input: GetMediaQuery): Promise<Result<MediaWithAuthor, DomainError>>;
}

export function createGetMediaUseCase(deps: GetMediaDeps): GetMediaUseCase {
  return {
    execute: async (input) => {
      const access = await deps.mediaRepository.findApartmentAccess(
        input.apartmentId,
        input.userId,
      );
      if (!access.ok) return access;
      if (access.value === null) return err(mediaNotFoundError(input.mediaId));
      if (!access.value.isActiveMember) return err(mediaAccessDeniedError(input.apartmentId));

      const found = await deps.mediaRepository.findByIdWithAuthor(input.mediaId);
      if (!found.ok) return found;
      if (
        found.value === null ||
        found.value.media.apartmentId !== input.apartmentId ||
        (found.value.media.uploadStatus !== 'uploaded' &&
          found.value.media.authorId !== input.userId)
      ) {
        return err(mediaNotFoundError(input.mediaId));
      }

      return ok(found.value);
    },
  };
}
