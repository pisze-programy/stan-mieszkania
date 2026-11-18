import { err, ok, type Result } from '@stanmieszkania/shared';
import { DECIMAL_RADIX, MARKER_TOKEN_REGEX } from './entries.constants';
import { entryValidationFailedError, type EntryError } from './entries.errors';
import { validateDraftMarkers, type DraftMarkerInput, type Marker } from './marker.entity';

export interface AssignGlobalMarkerNumbersInput {
  readonly entryId: string;
  readonly mediaId: string;
  readonly text: string;
  readonly draftMarkers: readonly DraftMarkerInput[];
  readonly currentMaxMarkerNumber: number;
}

export interface AssignedMarkerMapping {
  readonly localNumber: number;
  readonly assignedNumber: number;
  readonly markerId: string;
}

export interface AssignGlobalMarkerNumbersOutput {
  readonly text: string;
  readonly markers: readonly Marker[];
  readonly numberMapping: readonly AssignedMarkerMapping[];
  readonly nextMaxMarkerNumber: number;
}

// Decision S2-2 & Invariant 5: Assign monotonic global marker numbers and rewrite [n] tokens in one pass.
export function assignGlobalMarkerNumbers(
  input: AssignGlobalMarkerNumbersInput,
): Result<AssignGlobalMarkerNumbersOutput, EntryError> {
  if (!Number.isSafeInteger(input.currentMaxMarkerNumber) || input.currentMaxMarkerNumber < 0) {
    return err(
      entryValidationFailedError('Current max marker number must be a non-negative integer', {
        currentMaxMarkerNumber: input.currentMaxMarkerNumber,
      }),
    );
  }

  const validated = validateDraftMarkers(input.draftMarkers);
  if (!validated.ok) {
    return validated;
  }

  const localToGlobal = new Map<number, number>();
  const markers: Marker[] = [];
  const numberMapping: AssignedMarkerMapping[] = [];

  for (let index = 0; index < validated.value.length; index += 1) {
    const draft = validated.value[index];
    if (draft === undefined) {
      continue;
    }
    const assignedNumber = input.currentMaxMarkerNumber + index + 1;
    localToGlobal.set(draft.localNumber, assignedNumber);
    markers.push({
      id: draft.id,
      entryId: input.entryId,
      mediaId: input.mediaId,
      number: assignedNumber,
      x: draft.x,
      y: draft.y,
    });
    numberMapping.push({
      localNumber: draft.localNumber,
      assignedNumber,
      markerId: draft.id,
    });
  }

  const rewrittenText =
    localToGlobal.size === 0
      ? input.text
      : input.text.replace(MARKER_TOKEN_REGEX, (fullMatch, rawDigits: string) => {
          const parsedLocalNumber = Number.parseInt(rawDigits, DECIMAL_RADIX);
          if (String(parsedLocalNumber) !== rawDigits) {
            return fullMatch;
          }
          const assignedNumber = localToGlobal.get(parsedLocalNumber);
          return assignedNumber === undefined ? fullMatch : `[${String(assignedNumber)}]`;
        });

  return ok({
    text: rewrittenText,
    markers,
    numberMapping,
    nextMaxMarkerNumber: input.currentMaxMarkerNumber + markers.length,
  });
}
