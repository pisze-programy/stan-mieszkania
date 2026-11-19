import { err, type DomainError, type Result } from '@stanmieszkania/shared';
import { entryAccessDeniedError, entryNotFoundError } from '../domain/entries.errors';
import type { EntryRepository, EntryWithAuthor } from '../domain/entry.repository';

export interface ListMediaEntriesQuery {
  readonly apartmentId: string;
  readonly mediaId: string;
  readonly actorUserId: string;
}

export interface ListMediaEntriesDeps {
  readonly entryRepository: EntryRepository;
}

export interface ListMediaEntriesUseCase {
  execute(query: ListMediaEntriesQuery): Promise<Result<readonly EntryWithAuthor[], DomainError>>;
}

export function createListMediaEntriesUseCase(deps: ListMediaEntriesDeps): ListMediaEntriesUseCase {
  return {
    execute: async (query) => {
      const access = await deps.entryRepository.findApartmentMembership(
        query.apartmentId,
        query.actorUserId,
      );
      if (!access.ok) {
        return access;
      }
      if (access.value === null) {
        return err(entryNotFoundError(query.mediaId));
      }
      if (!access.value.isActiveMember) {
        return err(entryAccessDeniedError(query.apartmentId));
      }

      const targetMedia = await deps.entryRepository.findTargetMediaAccess(
        query.mediaId,
        query.actorUserId,
      );
      if (!targetMedia.ok) {
        return targetMedia;
      }
      if (targetMedia.value === null || targetMedia.value.apartmentId !== query.apartmentId) {
        return err(entryNotFoundError(query.mediaId));
      }

      return deps.entryRepository.listByMedia(query.mediaId);
    },
  };
}
