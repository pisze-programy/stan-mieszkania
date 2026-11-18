import { err, ok, type Result } from '@stanmieszkania/shared';
import { MARKER_COORD_MAX, MARKER_COORD_MIN, MIN_MARKER_NUMBER } from './entries.constants';
import {
  entryValidationFailedError,
  markerDuplicateLocalNumberError,
  markerInvalidCoordinatesError,
  type EntryError,
} from './entries.errors';

export interface Marker {
  readonly id: string;
  readonly entryId: string;
  readonly mediaId: string;
  readonly number: number;
  readonly x: number;
  readonly y: number;
}

export interface DraftMarkerInput {
  readonly id: string;
  readonly localNumber: number;
  readonly x: number;
  readonly y: number;
}

function isValidCoordinate(value: number): boolean {
  return Number.isFinite(value) && value >= MARKER_COORD_MIN && value <= MARKER_COORD_MAX;
}

export function validateDraftMarkers(
  draftMarkers: readonly DraftMarkerInput[],
): Result<readonly DraftMarkerInput[], EntryError> {
  const seenLocalNumbers = new Set<number>();
  const seenIds = new Set<string>();

  for (const draft of draftMarkers) {
    if (draft.id.trim().length === 0) {
      return err(entryValidationFailedError('Marker id must not be empty'));
    }
    if (seenIds.has(draft.id)) {
      return err(entryValidationFailedError(`Duplicate marker id: ${draft.id}`, { id: draft.id }));
    }
    seenIds.add(draft.id);

    if (!Number.isSafeInteger(draft.localNumber) || draft.localNumber < MIN_MARKER_NUMBER) {
      return err(
        entryValidationFailedError('Local marker number must be a positive integer', {
          localNumber: draft.localNumber,
        }),
      );
    }
    if (seenLocalNumbers.has(draft.localNumber)) {
      return err(markerDuplicateLocalNumberError(draft.localNumber));
    }
    seenLocalNumbers.add(draft.localNumber);

    if (!isValidCoordinate(draft.x) || !isValidCoordinate(draft.y)) {
      return err(markerInvalidCoordinatesError(draft.localNumber, draft.x, draft.y));
    }
  }

  return ok(draftMarkers);
}
