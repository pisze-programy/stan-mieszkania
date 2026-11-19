import { err, ok, type Clock, type DomainError, type Result } from '@stanmieszkania/shared';
import {
  entryAccessDeniedError,
  entryAuthorRequiredError,
  entryNotFoundError,
} from '../domain/entries.errors';
import { retractEntry } from '../domain/entry.entity';
import type { EntryRepository, EntryWithAuthor } from '../domain/entry.repository';

export interface RetractEntryCommand {
  readonly apartmentId: string;
  readonly mediaId: string;
  readonly entryId: string;
  readonly actorUserId: string;
}

export interface RetractEntryDeps {
  readonly entryRepository: EntryRepository;
  readonly clock: Clock;
}

export interface RetractEntryUseCase {
  execute(command: RetractEntryCommand): Promise<Result<EntryWithAuthor, DomainError>>;
}

export function createRetractEntryUseCase(deps: RetractEntryDeps): RetractEntryUseCase {
  return {
    execute: async (command) => {
      const access = await deps.entryRepository.findApartmentMembership(
        command.apartmentId,
        command.actorUserId,
      );
      if (!access.ok) {
        return access;
      }
      if (access.value === null) {
        return err(entryNotFoundError(command.entryId));
      }
      if (!access.value.isActiveMember) {
        return err(entryAccessDeniedError(command.apartmentId));
      }

      const targetMedia = await deps.entryRepository.findTargetMediaAccess(
        command.mediaId,
        command.actorUserId,
      );
      if (!targetMedia.ok) {
        return targetMedia;
      }
      if (targetMedia.value === null || targetMedia.value.apartmentId !== command.apartmentId) {
        return err(entryNotFoundError(command.entryId));
      }

      const existing = await deps.entryRepository.findByIdWithAuthor(command.entryId);
      if (!existing.ok) {
        return existing;
      }
      if (existing.value === null || existing.value.entry.mediaId !== command.mediaId) {
        return err(entryNotFoundError(command.entryId));
      }
      if (existing.value.entry.authorId !== command.actorUserId) {
        return err(entryAuthorRequiredError(command.entryId));
      }

      // Architecture A16: Replaying retraction by the same author is idempotent.
      if (existing.value.entry.retractedAt !== null) {
        return ok(existing.value);
      }

      const nowIso = deps.clock.nowIso();
      const retracted = retractEntry(existing.value.entry, {
        actorUserId: command.actorUserId,
        nowIso,
      });
      if (!retracted.ok) {
        return retracted;
      }

      const persisted = await deps.entryRepository.retract({
        entryId: command.entryId,
        apartmentId: command.apartmentId,
        retractedAt: nowIso,
      });
      if (!persisted.ok) {
        return persisted;
      }

      return ok({
        entry: {
          ...retracted.value,
          markers: [],
        },
        author: existing.value.author,
      });
    },
  };
}
