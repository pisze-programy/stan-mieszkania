import { err, ok, type Clock, type DomainError, type Result } from '@stanmieszkania/shared';
import {
  entryAccessDeniedError,
  entryConflictError,
  entryNotFoundError,
} from '../domain/entries.errors';
import { canAttachEntryToMedia, createVerifiedEntry } from '../domain/entry.entity';
import type { EntryRepository, EntryWithAuthor } from '../domain/entry.repository';
import type { DraftMarkerInput } from '../domain/marker.entity';

export interface CreateEntryCommand {
  readonly apartmentId: string;
  readonly mediaId: string;
  readonly entryId: string;
  readonly actorUserId: string;
  readonly text: string;
  readonly draftMarkers: readonly DraftMarkerInput[];
  readonly createdAt: string;
}

export interface CreateEntryDeps {
  readonly entryRepository: EntryRepository;
  readonly clock: Clock;
}

export interface CreateEntryUseCase {
  execute(command: CreateEntryCommand): Promise<Result<EntryWithAuthor, DomainError>>;
}

export function createCreateEntryUseCase(deps: CreateEntryDeps): CreateEntryUseCase {
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
        return err(entryNotFoundError(command.mediaId));
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
        return err(entryNotFoundError(command.mediaId));
      }

      const existing = await deps.entryRepository.findByIdWithAuthor(command.entryId);
      if (!existing.ok) {
        return existing;
      }
      if (existing.value !== null) {
        if (
          existing.value.entry.authorId === command.actorUserId &&
          existing.value.entry.mediaId === command.mediaId
        ) {
          return ok(existing.value);
        }
        return err(
          entryConflictError('Entry id already belongs to another author or media item', {
            entryId: command.entryId,
          }),
        );
      }

      const readiness = canAttachEntryToMedia(targetMedia.value, command.actorUserId);
      if (!readiness.ok) {
        return readiness;
      }

      const maxMarkerResult = await deps.entryRepository.getMaxMarkerNumber(command.mediaId);
      if (!maxMarkerResult.ok) {
        return maxMarkerResult;
      }

      const verified = createVerifiedEntry({
        id: command.entryId,
        mediaId: command.mediaId,
        authorId: command.actorUserId,
        text: command.text,
        draftMarkers: command.draftMarkers,
        currentMaxMarkerNumber: maxMarkerResult.value,
        createdAt: command.createdAt,
        serverReceivedAt: deps.clock.nowIso(),
      });
      if (!verified.ok) {
        return verified;
      }

      const inserted = await deps.entryRepository.insertWithMarkers({
        apartmentId: command.apartmentId,
        entry: verified.value.entry,
      });
      if (!inserted.ok) {
        // Recover from concurrent idempotent PUT replay on PK(entries.id).
        const replay = await deps.entryRepository.findByIdWithAuthor(command.entryId);
        if (replay.ok && replay.value !== null) {
          if (
            replay.value.entry.authorId === command.actorUserId &&
            replay.value.entry.mediaId === command.mediaId
          ) {
            return ok(replay.value);
          }
          return err(
            entryConflictError('Entry id already belongs to another author or media item', {
              entryId: command.entryId,
            }),
          );
        }
        return inserted;
      }

      const persisted = await deps.entryRepository.findByIdWithAuthor(command.entryId);
      if (!persisted.ok) {
        return persisted;
      }
      if (persisted.value === null) {
        return err(entryNotFoundError(command.entryId));
      }
      return ok(persisted.value);
    },
  };
}
