import type { D1Meta } from '@cloudflare/workers-types';
import { isErr } from '@stanmieszkania/shared';
import { describe, expect, it, vi } from 'vitest';
import { z } from 'zod';
import { DB_ERROR_CODES } from './db.errors';
import { defineTable } from './define-table';
import { verifyTableSchemas } from './schema-verifier';
import type { D1PreparedStatementLike, D1Queryable } from './statement';

const DEFAULT_META: D1Meta & Record<string, unknown> = {
  duration: 1,
  size_after: 0,
  rows_read: 0,
  rows_written: 0,
  last_row_id: 0,
  changed_db: false,
  changes: 0,
};

const unsupported = (): Promise<never> => Promise.reject(new Error('Unexpected D1 call'));

function createPragmaFakeDb(
  tableColumnsByName: Readonly<Record<string, readonly string[]>>,
): D1Queryable {
  return {
    prepare(sql: string): D1PreparedStatementLike<D1PreparedStatementLike> {
      const statement: D1PreparedStatementLike<D1PreparedStatementLike> = {
        bind(): D1PreparedStatementLike {
          return statement;
        },
        run: unsupported,
        // reason: D1PreparedStatementLike.all<T> is method-generic and cannot be typed without assertion in a fake.
        all: vi.fn(() => {
          const match = /^PRAGMA table_info\("([^"]+)"\)$/.exec(sql);
          const tableName = match?.[1] ?? '';
          const columns = tableColumnsByName[tableName] ?? [];
          return Promise.resolve({
            success: true as const,
            meta: DEFAULT_META,
            results: columns.map((name, index) => ({
              cid: index,
              name,
              type: 'TEXT',
              notnull: 1,
              dflt_value: null,
              pk: index === 0 ? 1 : 0,
            })),
          });
        }) as unknown as D1PreparedStatementLike['all'],
      };
      return statement;
    },
  };
}

describe('verifyTableSchemas rowSchema checks', () => {
  it('fails when rowSchema is missing a DB column even though columns map matches', async () => {
    const db = createPragmaFakeDb({ users: ['id', 'firebase_uid', 'display_name'] });
    const table = defineTable({
      name: 'users',
      columns: { id: 'id', firebaseUid: 'firebase_uid', displayName: 'display_name' } as const,
      rowSchema: z.object({ id: z.string(), firebase_uid: z.string() }),
    });

    const result = await verifyTableSchemas(db, [table]);

    expect(isErr(result)).toBe(true);
    if (isErr(result)) {
      expect(result.error.code).toBe(DB_ERROR_CODES.DB_SCHEMA_MISMATCH);
      expect(result.error.details).toEqual({
        mismatches: [
          {
            table: 'users',
            missingInDb: [],
            extraInDb: [],
            missingInRowSchema: ['display_name'],
            extraInRowSchema: [],
          },
        ],
      });
    }
  });

  it('fails when rowSchema uses camelCase or extra keys not present in DB', async () => {
    const db = createPragmaFakeDb({ users: ['id', 'display_name'] });
    const table = defineTable({
      name: 'users',
      columns: { id: 'id', displayName: 'display_name' } as const,
      rowSchema: z.object({ id: z.string(), displayName: z.string(), ghost: z.string() }),
    });

    const result = await verifyTableSchemas(db, [table]);

    expect(isErr(result)).toBe(true);
    if (isErr(result)) {
      expect(result.error.code).toBe(DB_ERROR_CODES.DB_SCHEMA_MISMATCH);
      expect(result.error.details).toEqual({
        mismatches: [
          {
            table: 'users',
            missingInDb: [],
            extraInDb: [],
            missingInRowSchema: ['display_name'],
            extraInRowSchema: ['displayName', 'ghost'],
          },
        ],
      });
    }
  });

  it('fails with nonObjectRowSchema when rowSchema is not a ZodObject', async () => {
    const db = createPragmaFakeDb({ users: ['id'] });
    const table = defineTable({
      name: 'users',
      columns: { id: 'id' } as const,
      rowSchema: z.string(),
    });

    const result = await verifyTableSchemas(db, [table]);

    expect(isErr(result)).toBe(true);
    if (isErr(result)) {
      expect(result.error.code).toBe(DB_ERROR_CODES.DB_SCHEMA_MISMATCH);
      expect(result.error.details).toEqual({
        mismatches: [
          {
            table: 'users',
            missingInDb: [],
            extraInDb: [],
            missingInRowSchema: [],
            extraInRowSchema: [],
            nonObjectRowSchema: true,
          },
        ],
      });
    }
  });

  it('unwraps ZodPipe transforms and refined ZodObjects when verifying keys', async () => {
    const db = createPragmaFakeDb({ users: ['id', 'display_name'] });
    const validPipedTable = defineTable({
      name: 'users',
      columns: { id: 'id', displayName: 'display_name' } as const,
      rowSchema: z
        .object({ id: z.string(), display_name: z.string() })
        .refine((row) => row.id.length > 0)
        .transform((row) => ({ id: row.id, displayName: row.display_name })),
    });

    expect(await verifyTableSchemas(db, [validPipedTable])).toEqual({
      ok: true,
      value: undefined,
    });

    const invalidPipedTable = defineTable({
      name: 'users',
      columns: { id: 'id', displayName: 'display_name' } as const,
      rowSchema: z
        .object({ id: z.string(), wrong_col: z.string() })
        .transform((row) => ({ id: row.id, displayName: row.wrong_col })),
    });

    const invalidResult = await verifyTableSchemas(db, [invalidPipedTable]);
    expect(isErr(invalidResult)).toBe(true);
    if (isErr(invalidResult)) {
      expect(invalidResult.error.details).toEqual({
        mismatches: [
          {
            table: 'users',
            missingInDb: [],
            extraInDb: [],
            missingInRowSchema: ['display_name'],
            extraInRowSchema: ['wrong_col'],
          },
        ],
      });
    }
  });
});
