import { createDomainError, type DomainError, type ErrorDetails } from '@stanmieszkania/shared';

export const DB_ERROR_CODES = {
  DB_QUERY_FAILED: 'DB_QUERY_FAILED',
  DB_ROW_VALIDATION_FAILED: 'DB_ROW_VALIDATION_FAILED',
  DB_EXECUTION_FAILED: 'DB_EXECUTION_FAILED',
  DB_BATCH_FAILED: 'DB_BATCH_FAILED',
  DB_SCHEMA_MISMATCH: 'DB_SCHEMA_MISMATCH',
} as const;

export type DbErrorCode = (typeof DB_ERROR_CODES)[keyof typeof DB_ERROR_CODES];

export type DbError = DomainError<DbErrorCode>;

function extractErrorMessage(cause: unknown): string {
  if (cause instanceof Error) {
    return cause.message;
  }
  return typeof cause === 'string' ? cause : 'Unknown database error';
}

export function createDbQueryFailedError(cause: unknown, details?: ErrorDetails): DbError {
  return createDomainError(
    DB_ERROR_CODES.DB_QUERY_FAILED,
    `Database query failed: ${extractErrorMessage(cause)}`,
    details,
  );
}

export function createDbRowValidationFailedError(message: string, details?: ErrorDetails): DbError {
  return createDomainError(DB_ERROR_CODES.DB_ROW_VALIDATION_FAILED, message, details);
}

export function createDbExecutionFailedError(cause: unknown, details?: ErrorDetails): DbError {
  return createDomainError(
    DB_ERROR_CODES.DB_EXECUTION_FAILED,
    `Database execution failed: ${extractErrorMessage(cause)}`,
    details,
  );
}

export function createDbBatchFailedError(cause: unknown, details?: ErrorDetails): DbError {
  return createDomainError(
    DB_ERROR_CODES.DB_BATCH_FAILED,
    `Database batch failed: ${extractErrorMessage(cause)}`,
    details,
  );
}

export function createDbSchemaMismatchError(message: string, details?: ErrorDetails): DbError {
  return createDomainError(DB_ERROR_CODES.DB_SCHEMA_MISMATCH, message, details);
}
