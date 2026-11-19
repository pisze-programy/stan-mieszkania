import { err, type DomainError, type Result } from '@stanmieszkania/shared';
import { SYNC_DEFAULT_PAGE_SIZE, SYNC_INITIAL_AFTER_SEQ } from '../domain/sync.constants';
import type { SyncChangesPage } from '../domain/sync.entity';
import {
  syncAccessDeniedError,
  syncApartmentNotFoundError,
  syncValidationFailedError,
} from '../domain/sync.errors';
import type { SyncRepository } from '../domain/sync.repository';

export interface ListApartmentChangesFeedDeps {
  readonly syncRepository: SyncRepository;
}

export interface ListApartmentChangesFeedQuery {
  readonly apartmentId: string;
  readonly userId: string;
  readonly after?: number;
  readonly limit?: number;
}

export interface ListApartmentChangesFeedUseCase {
  execute(input: ListApartmentChangesFeedQuery): Promise<Result<SyncChangesPage, DomainError>>;
}

export function createListApartmentChangesFeedUseCase(
  deps: ListApartmentChangesFeedDeps,
): ListApartmentChangesFeedUseCase {
  return {
    execute: async (input) => {
      const afterSeq = input.after ?? SYNC_INITIAL_AFTER_SEQ;
      const limit = input.limit ?? SYNC_DEFAULT_PAGE_SIZE;
      if (!Number.isInteger(afterSeq) || afterSeq < 0) {
        return err(syncValidationFailedError('after cursor must be a non-negative integer'));
      }
      if (!Number.isInteger(limit) || limit < 1) {
        return err(syncValidationFailedError('limit must be a positive integer'));
      }

      const access = await deps.syncRepository.findApartmentAccess(input.apartmentId, input.userId);
      if (!access.ok) return access;
      if (access.value === null) return err(syncApartmentNotFoundError(input.apartmentId));
      if (!access.value.isActiveMember) return err(syncAccessDeniedError(input.apartmentId));

      return deps.syncRepository.listChangesAfter({
        apartmentId: input.apartmentId,
        callerRole: access.value.role,
        afterSeq,
        limit,
      });
    },
  };
}
