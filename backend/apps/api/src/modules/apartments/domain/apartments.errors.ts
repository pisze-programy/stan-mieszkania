import { createDomainError, type DomainError, type ErrorDetails } from '@stanmieszkania/shared';

export const APARTMENT_ERROR_CODES = {
  APARTMENT_NOT_FOUND: 'APARTMENT_NOT_FOUND',
  APARTMENT_ACCESS_DENIED: 'APARTMENT_ACCESS_DENIED',
  APARTMENT_OWNER_REQUIRED: 'APARTMENT_OWNER_REQUIRED',
  APARTMENT_VALIDATION_FAILED: 'APARTMENT_VALIDATION_FAILED',
  INVITE_CODE_INVALID: 'INVITE_CODE_INVALID',
  INVITE_CODE_COLLISION: 'INVITE_CODE_COLLISION',
} as const;

export type ApartmentErrorCode = (typeof APARTMENT_ERROR_CODES)[keyof typeof APARTMENT_ERROR_CODES];
export type ApartmentError = DomainError<ApartmentErrorCode>;

export function apartmentNotFoundError(apartmentId: string): ApartmentError {
  return createDomainError(APARTMENT_ERROR_CODES.APARTMENT_NOT_FOUND, 'Apartment was not found', {
    apartmentId,
  });
}

export function apartmentAccessDeniedError(apartmentId: string): ApartmentError {
  return createDomainError(
    APARTMENT_ERROR_CODES.APARTMENT_ACCESS_DENIED,
    'User does not have access to this apartment',
    { apartmentId },
  );
}

export function apartmentOwnerRequiredError(apartmentId: string): ApartmentError {
  return createDomainError(
    APARTMENT_ERROR_CODES.APARTMENT_OWNER_REQUIRED,
    'Only the apartment owner can perform this action',
    { apartmentId },
  );
}

export function apartmentValidationFailedError(
  message: string,
  details?: ErrorDetails,
): ApartmentError {
  return createDomainError(APARTMENT_ERROR_CODES.APARTMENT_VALIDATION_FAILED, message, details);
}

export function inviteCodeInvalidError(message: string): ApartmentError {
  return createDomainError(APARTMENT_ERROR_CODES.INVITE_CODE_INVALID, message);
}

export function inviteCodeCollisionError(): ApartmentError {
  return createDomainError(
    APARTMENT_ERROR_CODES.INVITE_CODE_COLLISION,
    'Generated invite code collided with an existing apartment',
  );
}
