import type { D1PreparedStatement, D1Result } from '@cloudflare/workers-types';
import { err, ok, type Result } from '@stanmieszkania/shared';
import { createDbBatchFailedError, type DbError } from './db.errors';
import type { D1Client, D1PreparedStatementLike, SqlStatement } from './statement';

export async function executeBatch<
  TStatement extends D1PreparedStatementLike<TStatement> = D1PreparedStatement,
>(
  db: D1Client<TStatement>,
  statements: readonly SqlStatement[],
): Promise<Result<readonly D1Result[], DbError>> {
  if (statements.length === 0) {
    return ok([]);
  }

  try {
    const prepared = statements.map((statement) =>
      db.prepare(statement.sql).bind(...statement.params),
    );
    const results = await db.batch(prepared);
    return ok(results);
  } catch (cause: unknown) {
    return err(createDbBatchFailedError(cause, { statementCount: statements.length }));
  }
}
