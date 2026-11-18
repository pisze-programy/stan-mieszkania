import { describe, expect, it } from 'vitest';
import {
  DB_ERROR_CODES,
  createDbBatchFailedError,
  createDbExecutionFailedError,
  createDbQueryFailedError,
  createDbRowValidationFailedError,
  createDbSchemaMismatchError,
} from './db.errors';

describe('db.errors', () => {
  it('defines all expected DB_ERROR_CODES', () => {
    expect(DB_ERROR_CODES).toEqual({
      DB_QUERY_FAILED: 'DB_QUERY_FAILED',
      DB_ROW_VALIDATION_FAILED: 'DB_ROW_VALIDATION_FAILED',
      DB_EXECUTION_FAILED: 'DB_EXECUTION_FAILED',
      DB_BATCH_FAILED: 'DB_BATCH_FAILED',
      DB_SCHEMA_MISMATCH: 'DB_SCHEMA_MISMATCH',
    });
  });

  it('builds DB_QUERY_FAILED errors from Error, string, and unknown causes', () => {
    expect(createDbQueryFailedError(new Error('disk I/O error'), { sql: 'SELECT 1' })).toEqual({
      code: DB_ERROR_CODES.DB_QUERY_FAILED,
      message: 'Database query failed: disk I/O error',
      details: { sql: 'SELECT 1' },
    });

    expect(createDbQueryFailedError('timeout')).toEqual({
      code: DB_ERROR_CODES.DB_QUERY_FAILED,
      message: 'Database query failed: timeout',
    });

    expect(createDbQueryFailedError(1234)).toEqual({
      code: DB_ERROR_CODES.DB_QUERY_FAILED,
      message: 'Database query failed: Unknown database error',
    });
  });

  it('builds validation, execution, batch, and schema mismatch errors', () => {
    expect(createDbRowValidationFailedError('Invalid row', { rowIndex: 0 })).toEqual({
      code: DB_ERROR_CODES.DB_ROW_VALIDATION_FAILED,
      message: 'Invalid row',
      details: { rowIndex: 0 },
    });

    expect(createDbExecutionFailedError(new Error('constraint failed'))).toEqual({
      code: DB_ERROR_CODES.DB_EXECUTION_FAILED,
      message: 'Database execution failed: constraint failed',
    });

    expect(createDbBatchFailedError(new Error('batch rolled back'), { statementCount: 2 })).toEqual(
      {
        code: DB_ERROR_CODES.DB_BATCH_FAILED,
        message: 'Database batch failed: batch rolled back',
        details: { statementCount: 2 },
      },
    );

    expect(createDbSchemaMismatchError('Missing column', { table: 'users' })).toEqual({
      code: DB_ERROR_CODES.DB_SCHEMA_MISMATCH,
      message: 'Missing column',
      details: { table: 'users' },
    });
  });
});
