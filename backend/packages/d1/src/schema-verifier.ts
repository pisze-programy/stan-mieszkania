import { err, ok, type Result } from '@stanmieszkania/shared';
import { z, type ZodType } from 'zod';
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
  readonly missingInRowSchema: readonly string[];
  readonly extraInRowSchema: readonly string[];
  readonly nonObjectRowSchema?: true;
}

function extractRowSchemaColumns(schema: ZodType): readonly string[] | null {
  let current: unknown = schema;
  while (current instanceof z.ZodPipe) {
    const next: unknown = current.in;
    current = next;
  }
  if (current instanceof z.ZodObject) {
    const shape: Readonly<Record<string, unknown>> = current.shape;
    return Object.keys(shape);
  }
  return null;
}

function diffSets(source: ReadonlySet<string>, target: ReadonlySet<string>): readonly string[] {
  return [...source].filter((value) => !target.has(value)).sort();
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

    const missingInDb = diffSets(expectedColumns, actualColumns);
    const extraInDb = diffSets(actualColumns, expectedColumns);

    const rowSchemaColumns = extractRowSchemaColumns(table.rowSchema);
    const rowSchemaSet = rowSchemaColumns === null ? null : new Set(rowSchemaColumns);
    const missingInRowSchema = rowSchemaSet === null ? [] : diffSets(actualColumns, rowSchemaSet);
    const extraInRowSchema = rowSchemaSet === null ? [] : diffSets(rowSchemaSet, actualColumns);
    const nonObjectRowSchema = rowSchemaSet === null;

    if (
      missingInDb.length > 0 ||
      extraInDb.length > 0 ||
      missingInRowSchema.length > 0 ||
      extraInRowSchema.length > 0 ||
      nonObjectRowSchema
    ) {
      mismatches.push(
        nonObjectRowSchema
          ? {
              table: table.name,
              missingInDb,
              extraInDb,
              missingInRowSchema,
              extraInRowSchema,
              nonObjectRowSchema: true,
            }
          : {
              table: table.name,
              missingInDb,
              extraInDb,
              missingInRowSchema,
              extraInRowSchema,
            },
      );
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
