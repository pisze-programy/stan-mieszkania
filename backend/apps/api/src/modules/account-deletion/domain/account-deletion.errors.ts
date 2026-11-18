import { createDomainError, type DomainError, type ErrorDetails } from '@stanmieszkania/shared';

export const ACCOUNT_DELETION_ERROR_CODES = {
  ACCOUNT_DELETION_FAILED: 'ACCOUNT_DELETION_FAILED',
  EXTERNAL_AUTH_CLEANUP_FAILED: 'EXTERNAL_AUTH_CLEANUP_FAILED',
  INVALID_APPLE_AUTHORIZATION_CODE: 'INVALID_APPLE_AUTHORIZATION_CODE',
} as const;

export type AccountDeletionErrorCode =
  (typeof ACCOUNT_DELETION_ERROR_CODES)[keyof typeof ACCOUNT_DELETION_ERROR_CODES];

export type AccountDeletionError = DomainError<AccountDeletionErrorCode>;

export function accountDeletionFailedError(
  message: string,
  details?: ErrorDetails,
): AccountDeletionError {
  return createDomainError(ACCOUNT_DELETION_ERROR_CODES.ACCOUNT_DELETION_FAILED, message, details);
}

export function externalAuthCleanupFailedError(
  message: string,
  details?: ErrorDetails,
): AccountDeletionError {
  return createDomainError(
    ACCOUNT_DELETION_ERROR_CODES.EXTERNAL_AUTH_CLEANUP_FAILED,
    message,
    details,
  );
}

export function invalidAppleAuthorizationCodeError(message: string): AccountDeletionError {
  return createDomainError(ACCOUNT_DELETION_ERROR_CODES.INVALID_APPLE_AUTHORIZATION_CODE, message);
}
