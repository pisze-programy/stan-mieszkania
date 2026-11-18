import { err, ok, type Result } from '@stanmieszkania/shared';
import { z } from 'zod';
import { createDbSchemaMismatchError, type DbError } from './db.errors';
import type { TableSchemaDescriptor } from './define-table';
import { query } from './query';
import { createStatement, type D1Queryable } from './statement';

const SQLITE_IDENTIFIER_PATTERN = /^[A-Za-z_][A-Za-z0-9_]*$/;

const pragmaTableInfoRowSchema = z.object({
  name: z.string(),
});

export interface TableSchemaMismatch {
  readonly table: string;
  readonly missingInDb: readonly string[];
  readonly extraInDb: readonly string[];
}

export async function verifyTableSchemas(
  db: D1Queryable,
  tables: readonly TableSchemaDescriptor[],
): Promise<Result<void, DbError>> {
  const mismatches: TableSchemaMismatch[] = [];

  for (const table of tables) {
    // Security invariant: PRAGMA table_info does not support bind parameters; validate identifier strictly.
    if (!SQLITE_IDENTIFIER_PATTERN.test(table.name)) {
      return err(
        createDbSchemaMismatchError(`Invalid SQLite table identifier: ${table.name}`, {
          table: table.name,
        }),
      );
    }

    const pragmaResult = await query(
      db,
      createStatement(`PRAGMA table_info("${table.name}")`),
      pragmaTableInfoRowSchema,
    );
    if (!pragmaResult.ok) {
      return pragmaResult;
    }

    const expectedColumns = new Set(Object.values(table.columns));
    const actualColumns = new Set(pragmaResult.value.map((row) => row.name));

    const missingInDb = [...expectedColumns].filter((column) => !actualColumns.has(column)).sort();
    const extraInDb = [...actualColumns].filter((column) => !expectedColumns.has(column)).sort();

    if (missingInDb.length > 0 || extraInDb.length > 0) {
      mismatches.push({
        table: table.name,
        missingInDb,
        extraInDb,
      });
    }
  }

  if (mismatches.length > 0) {
    const affectedTables = mismatches.map((mismatch) => mismatch.table).join(', ');
    return err(
      createDbSchemaMismatchError(
        `Schema mismatch detected in ${String(mismatches.length)} table(s): ${affectedTables}`,
        { mismatches },
      ),
    );
  }

  return ok();
}
