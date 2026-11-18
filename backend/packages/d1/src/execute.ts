import { err, ok, type Result } from '@stanmieszkania/shared';
import { createDbExecutionFailedError, type DbError } from './db.errors';
import type { D1Queryable, SqlStatement } from './statement';

export interface ExecutionResult {
  readonly changes: number;
  readonly lastRowId: number | null;
}

export async function execute(
  db: D1Queryable,
  statement: SqlStatement,
): Promise<Result<ExecutionResult, DbError>> {
  try {
    const response = await db
      .prepare(statement.sql)
      .bind(...statement.params)
      .run();
    const rawChanges: unknown = response.meta.changes;
    const rawLastRowId: unknown = response.meta.last_row_id;

    return ok({
      changes: typeof rawChanges === 'number' ? rawChanges : 0,
      lastRowId: typeof rawLastRowId === 'number' && rawLastRowId !== 0 ? rawLastRowId : null,
    });
  } catch (cause: unknown) {
    return err(createDbExecutionFailedError(cause, { sql: statement.sql }));
  }
}
