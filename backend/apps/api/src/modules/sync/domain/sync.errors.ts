import { createDomainError, type DomainError, type ErrorDetails } from '@stanmieszkania/shared';

export const SYNC_ERROR_CODES = {
  SYNC_APARTMENT_NOT_FOUND: 'SYNC_APARTMENT_NOT_FOUND',
  SYNC_ACCESS_DENIED: 'SYNC_ACCESS_DENIED',
  SYNC_VALIDATION_FAILED: 'SYNC_VALIDATION_FAILED',
} as const;

export type SyncErrorCode = (typeof SYNC_ERROR_CODES)[keyof typeof SYNC_ERROR_CODES];
export type SyncError = DomainError<SyncErrorCode>;

export function syncApartmentNotFoundError(apartmentId: string): SyncError {
  return createDomainError(SYNC_ERROR_CODES.SYNC_APARTMENT_NOT_FOUND, 'Apartment was not found', {
    apartmentId,
  });
}

export function syncAccessDeniedError(apartmentId: string): SyncError {
  return createDomainError(
    SYNC_ERROR_CODES.SYNC_ACCESS_DENIED,
    'User does not have active membership in this apartment',
    { apartmentId },
  );
}

export function syncValidationFailedError(message: string, details?: ErrorDetails): SyncError {
  return createDomainError(SYNC_ERROR_CODES.SYNC_VALIDATION_FAILED, message, details);
}
