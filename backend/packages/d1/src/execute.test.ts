import { isErr } from '@stanmieszkania/shared';
import { describe, expect, it, vi } from 'vitest';
import { DB_ERROR_CODES } from './db.errors';
import { execute } from './execute';
import { createStatement, type D1PreparedStatementLike, type D1Queryable } from './statement';

const unsupported = (): Promise<never> => Promise.reject(new Error('Unexpected D1 call'));

type ExecuteHandler = (
  sql: string,
  params: readonly unknown[],
) => Promise<{ changes: number; lastRowId: number }>;

function createExecuteFakeDb(handler: ExecuteHandler): D1Queryable {
  return {
    prepare(sql: string): D1PreparedStatementLike<D1PreparedStatementLike> {
      let boundParams: readonly unknown[] = [];

      const statement: D1PreparedStatementLike<D1PreparedStatementLike> = {
        bind(...values: unknown[]): D1PreparedStatementLike {
          boundParams = values;
          return statement;
        },
        all: unsupported,
        run: vi.fn(async () => {
          const outcome = await handler(sql, boundParams);
          return {
            success: true as const,
            results: [],
            meta: {
              duration: 1,
              size_after: 0,
              rows_read: 0,
              rows_written: outcome.changes,
              last_row_id: outcome.lastRowId,
              changed_db: outcome.changes > 0,
              changes: outcome.changes,
            },
          };
        }),
      };

      return statement;
    },
  };
}

describe('execute', () => {
  it('runs a bound mutation and returns changes and lastRowId', async () => {
    const captured: { sql: string; params: readonly unknown[] }[] = [];
    const db = createExecuteFakeDb((sql, params) => {
      captured.push({ sql, params });
      return Promise.resolve({ changes: 1, lastRowId: 42 });
    });

    const result = await execute(
      db,
      createStatement('INSERT INTO apartments (id, name) VALUES (?, ?)', ['apt-1', 'Flat A']),
    );

    expect(captured).toEqual([
      { sql: 'INSERT INTO apartments (id, name) VALUES (?, ?)', params: ['apt-1', 'Flat A'] },
    ]);
    expect(result).toEqual({
      ok: true,
      value: { changes: 1, lastRowId: 42 },
    });
  });

  it('normalizes zero last_row_id to null', async () => {
    const db = createExecuteFakeDb(() => Promise.resolve({ changes: 2, lastRowId: 0 }));

    const result = await execute(
      db,
      createStatement('UPDATE apartments SET name = ? WHERE city = ?', ['Updated', 'Warsaw']),
    );

    expect(result).toEqual({
      ok: true,
      value: { changes: 2, lastRowId: null },
    });
  });

  it('returns DB_EXECUTION_FAILED when D1 throws', async () => {
    const db = createExecuteFakeDb(() =>
      Promise.reject(new Error('UNIQUE constraint failed: apartments.invite_code')),
    );
    const statement = createStatement('INSERT INTO apartments (id) VALUES (?)', ['apt-1']);

    const result = await execute(db, statement);

    expect(isErr(result)).toBe(true);
    if (isErr(result)) {
      expect(result.error.code).toBe(DB_ERROR_CODES.DB_EXECUTION_FAILED);
      expect(result.error.message).toContain('UNIQUE constraint failed');
      expect(result.error.details).toEqual({ sql: statement.sql });
    }
  });
});
