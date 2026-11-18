import { createDomainError, type DomainError, type ErrorDetails } from '@stanmieszkania/shared';

export const ENTRY_ERROR_CODES = {
  ENTRY_NOT_FOUND: 'ENTRY_NOT_FOUND',
  ENTRY_ACCESS_DENIED: 'ENTRY_ACCESS_DENIED',
  ENTRY_AUTHOR_REQUIRED: 'ENTRY_AUTHOR_REQUIRED',
  ENTRY_VALIDATION_FAILED: 'ENTRY_VALIDATION_FAILED',
  ENTRY_ALREADY_RETRACTED: 'ENTRY_ALREADY_RETRACTED',
  ENTRY_MEDIA_NOT_READY: 'ENTRY_MEDIA_NOT_READY',
  ENTRY_CONFLICT: 'ENTRY_CONFLICT',
  MARKER_INVALID_COORDINATES: 'MARKER_INVALID_COORDINATES',
  MARKER_DUPLICATE_LOCAL_NUMBER: 'MARKER_DUPLICATE_LOCAL_NUMBER',
} as const;

export type EntryErrorCode = (typeof ENTRY_ERROR_CODES)[keyof typeof ENTRY_ERROR_CODES];
export type EntryError = DomainError<EntryErrorCode>;

export function entryNotFoundError(entryId: string): EntryError {
  return createDomainError(ENTRY_ERROR_CODES.ENTRY_NOT_FOUND, 'Entry was not found', { entryId });
}

export function entryAccessDeniedError(apartmentId: string): EntryError {
  return createDomainError(
    ENTRY_ERROR_CODES.ENTRY_ACCESS_DENIED,
    'User does not have access to entries in this apartment',
    { apartmentId },
  );
}

export function entryAuthorRequiredError(entryId: string): EntryError {
  return createDomainError(
    ENTRY_ERROR_CODES.ENTRY_AUTHOR_REQUIRED,
    'Only the entry author can retract this entry',
    { entryId },
  );
}

export function entryValidationFailedError(message: string, details?: ErrorDetails): EntryError {
  return createDomainError(ENTRY_ERROR_CODES.ENTRY_VALIDATION_FAILED, message, details);
}

export function entryAlreadyRetractedError(entryId: string): EntryError {
  return createDomainError(
    ENTRY_ERROR_CODES.ENTRY_ALREADY_RETRACTED,
    'Entry has already been retracted',
    { entryId },
  );
}

export function entryMediaNotReadyError(mediaId: string, message: string): EntryError {
  return createDomainError(ENTRY_ERROR_CODES.ENTRY_MEDIA_NOT_READY, message, { mediaId });
}

export function entryConflictError(message: string, details?: ErrorDetails): EntryError {
  return createDomainError(ENTRY_ERROR_CODES.ENTRY_CONFLICT, message, details);
}

export function markerInvalidCoordinatesError(
  localNumber: number,
  x: number,
  y: number,
): EntryError {
  return createDomainError(
    ENTRY_ERROR_CODES.MARKER_INVALID_COORDINATES,
    'Marker coordinates must be finite numbers within [0, 1]',
    { localNumber, x, y },
  );
}

export function markerDuplicateLocalNumberError(localNumber: number): EntryError {
  return createDomainError(
    ENTRY_ERROR_CODES.MARKER_DUPLICATE_LOCAL_NUMBER,
    `Duplicate local marker number: ${String(localNumber)}`,
    { localNumber },
  );
}
