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

const usersTable = defineTable({
  name: 'users',
  columns: {
    id: 'id',
    firebaseUid: 'firebase_uid',
    displayName: 'display_name',
  } as const,
  rowSchema: z.object({
    id: z.string(),
    firebase_uid: z.string(),
    display_name: z.string(),
  }),
});

const apartmentsTable = defineTable({
  name: 'apartments',
  columns: {
    id: 'id',
    ownerId: 'owner_id',
    name: 'name',
  } as const,
  rowSchema: z.object({
    id: z.string(),
    owner_id: z.string(),
    name: z.string(),
  }),
});

describe('verifyTableSchemas', () => {
  it('succeeds when all tables match SQLite columns bidirectionally', async () => {
    const db = createPragmaFakeDb({
      users: ['id', 'firebase_uid', 'display_name'],
      apartments: ['id', 'owner_id', 'name'],
    });

    const result = await verifyTableSchemas(db, [usersTable, apartmentsTable]);

    expect(result).toEqual({ ok: true, value: undefined });
  });

  it('fails with DB_SCHEMA_MISMATCH when an expected column is missing in DB', async () => {
    const db = createPragmaFakeDb({
      users: ['id', 'firebase_uid'],
    });

    const result = await verifyTableSchemas(db, [usersTable]);

    expect(isErr(result)).toBe(true);
    if (isErr(result)) {
      expect(result.error.code).toBe(DB_ERROR_CODES.DB_SCHEMA_MISMATCH);
      expect(result.error.details).toEqual({
        mismatches: [
          {
            table: 'users',
            missingInDb: ['display_name'],
            extraInDb: [],
          },
        ],
      });
    }
  });

  it('fails with DB_SCHEMA_MISMATCH when DB contains an extra undocumented column', async () => {
    const db = createPragmaFakeDb({
      users: ['id', 'firebase_uid', 'display_name', 'legacy_flag'],
    });

    const result = await verifyTableSchemas(db, [usersTable]);

    expect(isErr(result)).toBe(true);
    if (isErr(result)) {
      expect(result.error.code).toBe(DB_ERROR_CODES.DB_SCHEMA_MISMATCH);
      expect(result.error.details).toEqual({
        mismatches: [
          {
            table: 'users',
            missingInDb: [],
            extraInDb: ['legacy_flag'],
          },
        ],
      });
    }
  });

  it('aggregates mismatches across multiple tables', async () => {
    const db = createPragmaFakeDb({
      users: ['id', 'extra_col'],
      apartments: ['id', 'owner_id', 'name', 'city'],
    });

    const result = await verifyTableSchemas(db, [usersTable, apartmentsTable]);

    expect(isErr(result)).toBe(true);
    if (isErr(result)) {
      expect(result.error.code).toBe(DB_ERROR_CODES.DB_SCHEMA_MISMATCH);
      expect(result.error.details).toEqual({
        mismatches: [
          {
            table: 'users',
            missingInDb: ['display_name', 'firebase_uid'],
            extraInDb: ['extra_col'],
          },
          {
            table: 'apartments',
            missingInDb: [],
            extraInDb: ['city'],
          },
        ],
      });
    }
  });

  it('rejects invalid SQLite table identifiers before issuing PRAGMA', async () => {
    const prepareSpy = vi.fn<D1Queryable['prepare']>();
    const db: D1Queryable = {
      prepare: prepareSpy,
    };

    const invalidTable = defineTable({
      name: 'users"; DROP TABLE users; --',
      columns: { id: 'id' } as const,
      rowSchema: z.object({ id: z.string() }),
    });

    const result = await verifyTableSchemas(db, [invalidTable]);

    expect(prepareSpy).not.toHaveBeenCalled();
    expect(isErr(result)).toBe(true);
    if (isErr(result)) {
      expect(result.error.code).toBe(DB_ERROR_CODES.DB_SCHEMA_MISMATCH);
    }
  });

  it('propagates DB_QUERY_FAILED when PRAGMA query throws', async () => {
    const db: D1Queryable = {
      prepare(): D1PreparedStatementLike<D1PreparedStatementLike> {
        const statement: D1PreparedStatementLike<D1PreparedStatementLike> = {
          bind(): D1PreparedStatementLike {
            return statement;
          },
          run: unsupported,
          all: (): Promise<never> => Promise.reject(new Error('DB offline')),
        };
        return statement;
      },
    };

    const result = await verifyTableSchemas(db, [usersTable]);

    expect(isErr(result)).toBe(true);
    if (isErr(result)) {
      expect(result.error.code).toBe(DB_ERROR_CODES.DB_QUERY_FAILED);
    }
  });
});
