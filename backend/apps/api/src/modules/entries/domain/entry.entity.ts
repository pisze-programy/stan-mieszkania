import { err, ok, type Result } from '@stanmieszkania/shared';
import {
  ENTRY_TEXT_MAX_LENGTH,
  ENTRY_TEXT_MIN_LENGTH,
  REDACTED_ENTRY_TEXT,
} from './entries.constants';
import {
  entryAlreadyRetractedError,
  entryAuthorRequiredError,
  entryMediaNotReadyError,
  entryValidationFailedError,
  type EntryError,
} from './entries.errors';
import { assignGlobalMarkerNumbers, type AssignedMarkerMapping } from './marker-numbering.policy';
import type { DraftMarkerInput, Marker } from './marker.entity';

export interface Entry {
  readonly id: string;
  readonly mediaId: string;
  readonly authorId: string;
  readonly text: string;
  readonly markers: readonly Marker[];
  readonly createdAt: string;
  readonly serverReceivedAt: string;
  readonly retractedAt: string | null;
}

export interface CreateVerifiedEntryInput {
  readonly id: string;
  readonly mediaId: string;
  readonly authorId: string;
  readonly text: string;
  readonly draftMarkers: readonly DraftMarkerInput[];
  readonly currentMaxMarkerNumber: number;
  readonly createdAt: string;
  readonly serverReceivedAt: string;
}

export interface CreateVerifiedEntryResult {
  readonly entry: Entry;
  readonly numberMapping: readonly AssignedMarkerMapping[];
}

export interface RetractEntryInput {
  readonly actorUserId: string;
  readonly nowIso: string;
}

export interface TargetMediaReadiness {
  readonly mediaId: string;
  readonly authorId: string;
  readonly uploadStatus: 'pending' | 'uploaded';
  readonly deletedAt: string | null;
}

// Invariant 7: Cloud entries require non-deleted media that is uploaded or the author's own pending upload.
export function canAttachEntryToMedia(
  media: TargetMediaReadiness,
  actorUserId: string,
): Result<void, EntryError> {
  if (media.deletedAt !== null) {
    return err(
      entryMediaNotReadyError(media.mediaId, 'Cannot attach an entry to a deleted media item'),
    );
  }
  if (media.uploadStatus === 'uploaded' || media.authorId === actorUserId) {
    return ok();
  }
  return err(entryMediaNotReadyError(media.mediaId, 'Media upload has not been confirmed yet'));
}

export function createVerifiedEntry(
  input: CreateVerifiedEntryInput,
): Result<CreateVerifiedEntryResult, EntryError> {
  const trimmedText = input.text.trim();
  if (trimmedText.length < ENTRY_TEXT_MIN_LENGTH) {
    return err(entryValidationFailedError('Entry text must not be empty'));
  }
  if (trimmedText.length > ENTRY_TEXT_MAX_LENGTH) {
    return err(
      entryValidationFailedError(
        `Entry text must not exceed ${String(ENTRY_TEXT_MAX_LENGTH)} characters`,
        { maxLength: ENTRY_TEXT_MAX_LENGTH },
      ),
    );
  }

  const numbered = assignGlobalMarkerNumbers({
    entryId: input.id,
    mediaId: input.mediaId,
    text: trimmedText,
    draftMarkers: input.draftMarkers,
    currentMaxMarkerNumber: input.currentMaxMarkerNumber,
  });
  if (!numbered.ok) {
    return numbered;
  }

  return ok({
    entry: {
      id: input.id,
      mediaId: input.mediaId,
      authorId: input.authorId,
      text: numbered.value.text,
      markers: numbered.value.markers,
      createdAt: input.createdAt,
      serverReceivedAt: input.serverReceivedAt,
      retractedAt: null,
    },
    numberMapping: numbered.value.numberMapping,
  });
}

// Decision S2-3: Author-only retraction redacts entry text while keeping timestamps and marker numbers intact.
export function retractEntry(entry: Entry, input: RetractEntryInput): Result<Entry, EntryError> {
  if (entry.authorId !== input.actorUserId) {
    return err(entryAuthorRequiredError(entry.id));
  }
  if (entry.retractedAt !== null) {
    return err(entryAlreadyRetractedError(entry.id));
  }

  return ok({
    ...entry,
    text: REDACTED_ENTRY_TEXT,
    retractedAt: input.nowIso,
  });
}

export function isEntryVerified(entry: Entry): boolean {
  return entry.serverReceivedAt.length > 0;
}

export function isEntryRetracted(entry: Entry): boolean {
  return entry.retractedAt !== null;
}
