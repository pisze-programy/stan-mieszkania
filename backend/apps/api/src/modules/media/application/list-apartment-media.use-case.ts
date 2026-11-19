import {
  DEFAULT_PAGE_SIZE,
  err,
  type CursorPage,
  type DomainError,
  type Result,
} from '@stanmieszkania/shared';
import { mediaAccessDeniedError, mediaNotFoundError } from '../domain/media.errors';
import type { MediaRepository, MediaWithAuthor } from '../domain/media.repository';

export interface ListApartmentMediaDeps {
  readonly mediaRepository: MediaRepository;
}

export interface ListApartmentMediaQuery {
  readonly apartmentId: string;
  readonly userId: string;
  readonly after?: string;
  readonly limit?: number;
}

export interface ListApartmentMediaUseCase {
  execute(
    input: ListApartmentMediaQuery,
  ): Promise<Result<CursorPage<MediaWithAuthor, string>, DomainError>>;
}

export function createListApartmentMediaUseCase(
  deps: ListApartmentMediaDeps,
): ListApartmentMediaUseCase {
  return {
    execute: async (input) => {
      const access = await deps.mediaRepository.findApartmentAccess(
        input.apartmentId,
        input.userId,
      );
      if (!access.ok) return access;
      if (access.value === null) return err(mediaNotFoundError(input.apartmentId));
      if (!access.value.isActiveMember) return err(mediaAccessDeniedError(input.apartmentId));

      return deps.mediaRepository.listByApartment({
        apartmentId: input.apartmentId,
        viewerUserId: input.userId,
        ...(input.after !== undefined ? { after: input.after } : {}),
        limit: input.limit ?? DEFAULT_PAGE_SIZE,
      });
    },
  };
}
