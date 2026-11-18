import { err, ok, type Result } from '@stanmieszkania/shared';
import type { ZodType } from 'zod';
import {
  createDbQueryFailedError,
  createDbRowValidationFailedError,
  type DbError,
} from './db.errors';
import type { D1Queryable, SqlStatement } from './statement';

export async function query<TRow>(
  db: D1Queryable,
  statement: SqlStatement,
  rowSchema: ZodType<TRow>,
): Promise<Result<readonly TRow[], DbError>> {
  let rawResults: readonly unknown[];
  try {
    const response = await db
      .prepare(statement.sql)
      .bind(...statement.params)
      .all();
    rawResults = response.results;
  } catch (cause: unknown) {
    return err(createDbQueryFailedError(cause, { sql: statement.sql }));
  }

  const parsedRows: TRow[] = [];
  for (let rowIndex = 0; rowIndex < rawResults.length; rowIndex += 1) {
    const parsed = rowSchema.safeParse(rawResults[rowIndex]);
    if (!parsed.success) {
      return err(
        createDbRowValidationFailedError(`Row validation failed at index ${String(rowIndex)}`, {
          sql: statement.sql,
          rowIndex,
          issues: parsed.error.issues,
        }),
      );
    }
    parsedRows.push(parsed.data);
  }

  return ok(parsedRows);
}

export async function queryFirst<TRow>(
  db: D1Queryable,
  statement: SqlStatement,
  rowSchema: ZodType<TRow>,
): Promise<Result<TRow | null, DbError>> {
  const result = await query(db, statement, rowSchema);
  if (!result.ok) {
    return result;
  }
  const [firstRow] = result.value;
  return ok(firstRow === undefined ? null : firstRow);
}
