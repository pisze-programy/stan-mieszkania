import { createDomainError, type DomainError } from '@stanmieszkania/shared';

export const IDENTITY_ERROR_CODES = {
  AUTH_TOKEN_MISSING: 'AUTH_TOKEN_MISSING',
  AUTH_TOKEN_INVALID: 'AUTH_TOKEN_INVALID',
  USER_NOT_FOUND: 'USER_NOT_FOUND',
  USER_DELETED: 'USER_DELETED',
  DISPLAY_NAME_INVALID: 'DISPLAY_NAME_INVALID',
} as const;

export type IdentityErrorCode = (typeof IDENTITY_ERROR_CODES)[keyof typeof IDENTITY_ERROR_CODES];
export type IdentityError = DomainError<IdentityErrorCode>;

export function authTokenMissingError(): IdentityError {
  return createDomainError(
    IDENTITY_ERROR_CODES.AUTH_TOKEN_MISSING,
    'Authorization bearer token is missing',
  );
}

export function authTokenInvalidError(reason?: string): IdentityError {
  return createDomainError(
    IDENTITY_ERROR_CODES.AUTH_TOKEN_INVALID,
    reason ?? 'Authorization token is invalid or expired',
  );
}

export function userNotFoundError(userId: string): IdentityError {
  return createDomainError(IDENTITY_ERROR_CODES.USER_NOT_FOUND, 'User was not found', { userId });
}

export function userDeletedError(userId: string): IdentityError {
  return createDomainError(IDENTITY_ERROR_CODES.USER_DELETED, 'User account has been deleted', {
    userId,
  });
}

export function displayNameInvalidError(message: string): IdentityError {
  return createDomainError(IDENTITY_ERROR_CODES.DISPLAY_NAME_INVALID, message);
}
