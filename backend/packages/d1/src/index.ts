export {
  DB_ERROR_CODES,
  createDbBatchFailedError,
  createDbExecutionFailedError,
  createDbQueryFailedError,
  createDbRowValidationFailedError,
  createDbSchemaMismatchError,
  type DbError,
  type DbErrorCode,
} from './db.errors';

export {
  defineTable,
  type DefineTableInput,
  type TableColumns,
  type TableDefinition,
  type TableRow,
  type TableSchemaDescriptor,
} from './define-table';

export {
  createStatement,
  type D1Client,
  type D1PreparedStatementLike,
  type D1Queryable,
  type SqlParam,
  type SqlStatement,
} from './statement';

export { query, queryFirst } from './query';

export { execute, type ExecutionResult } from './execute';

export { executeBatch } from './batch';

export { verifyTableSchemas, type TableSchemaMismatch } from './schema-verifier';
