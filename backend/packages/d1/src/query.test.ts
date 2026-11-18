import type { D1Database, D1DatabaseSession, D1Meta } from '@cloudflare/workers-types';
import { isErr, isOk } from '@stanmieszkania/shared';
import { describe, expect, expectTypeOf, it, vi } from 'vitest';
import { z } from 'zod';
import { DB_ERROR_CODES } from './db.errors';
import { query, queryFirst } from './query';
import { createStatement, type D1PreparedStatementLike, type D1Queryable } from './statement';

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

function createQueryFakeDb(
  handler: (sql: string, params: readonly unknown[]) => Promise<readonly unknown[]>,
): D1Queryable {
  return {
    prepare(sql: string): D1PreparedStatementLike<D1PreparedStatementLike> {
      let boundParams: readonly unknown[] = [];

      const statement: D1PreparedStatementLike<D1PreparedStatementLike> = {
        bind(...values: unknown[]): D1PreparedStatementLike {
          boundParams = values;
          return statement;
        },
        run: unsupported,
        // reason: D1PreparedStatementLike.all<T> is method-generic and cannot be typed without assertion in a fake.
        all: vi.fn(async () => ({
          success: true as const,
          meta: DEFAULT_META,
          results: [...(await handler(sql, boundParams))],
        })) as unknown as D1PreparedStatementLike['all'],
      };

      return statement;
    },
  };
}

const userRowSchema = z.object({
  id: z.string(),
  name: z.string(),
  age: z.number().int(),
});

describe('query and queryFirst', () => {
  it('accepts Cloudflare D1Database and D1DatabaseSession types', () => {
    expectTypeOf<D1Database>().toExtend<D1Queryable>();
    expectTypeOf<D1DatabaseSession>().toExtend<D1Queryable>();
  });

  it('executes bound SQL and returns validated rows from query', async () => {
    const captured: { sql: string; params: readonly unknown[] }[] = [];
    const db = createQueryFakeDb((sql, params) => {
      captured.push({ sql, params });
      return Promise.resolve([
        { id: 'u1', name: 'Anna', age: 31 },
        { id: 'u2', name: 'Jan', age: 29 },
      ]);
    });

    const result = await query(
      db,
      createStatement('SELECT id, name, age FROM users WHERE age >= ?', [25]),
      userRowSchema,
    );

    expect(captured).toEqual([
      { sql: 'SELECT id, name, age FROM users WHERE age >= ?', params: [25] },
    ]);
    expect(isOk(result)).toBe(true);
    if (isOk(result)) {
      expect(result.value).toEqual([
        { id: 'u1', name: 'Anna', age: 31 },
        { id: 'u2', name: 'Jan', age: 29 },
      ]);
    }
  });

  it('returns an empty array for query and null for queryFirst when no rows match', async () => {
    const db = createQueryFakeDb(() => Promise.resolve([]));
    const statement = createStatement('SELECT id, name, age FROM users WHERE id = ?', ['missing']);

    const listResult = await query(db, statement, userRowSchema);
    expect(listResult).toEqual({ ok: true, value: [] });

    const firstResult = await queryFirst(db, statement, userRowSchema);
    expect(firstResult).toEqual({ ok: true, value: null });
  });

  it('returns the first validated row in queryFirst', async () => {
    const db = createQueryFakeDb(() =>
      Promise.resolve([
        { id: 'u1', name: 'Anna', age: 31 },
        { id: 'u2', name: 'Jan', age: 29 },
      ]),
    );

    const result = await queryFirst(
      db,
      createStatement('SELECT id, name, age FROM users'),
      userRowSchema,
    );

    expect(result).toEqual({ ok: true, value: { id: 'u1', name: 'Anna', age: 31 } });
  });

  it('returns DB_ROW_VALIDATION_FAILED when any row fails Zod validation', async () => {
    const db = createQueryFakeDb(() =>
      Promise.resolve([
        { id: 'u1', name: 'Anna', age: 31 },
        { id: 'u2', name: 'Jan', age: 'not-a-number' },
      ]),
    );

    const result = await query(
      db,
      createStatement('SELECT id, name, age FROM users'),
      userRowSchema,
    );

    expect(isErr(result)).toBe(true);
    if (isErr(result)) {
      expect(result.error.code).toBe(DB_ERROR_CODES.DB_ROW_VALIDATION_FAILED);
      expect(result.error.message).toContain('index 1');
      expect(result.error.details?.['rowIndex']).toBe(1);
      expect(Array.isArray(result.error.details?.['issues'])).toBe(true);
    }

    const firstResult = await queryFirst(
      db,
      createStatement('SELECT id, name, age FROM users'),
      userRowSchema,
    );
    expect(isErr(firstResult)).toBe(true);
    if (isErr(firstResult)) {
      expect(firstResult.error.code).toBe(DB_ERROR_CODES.DB_ROW_VALIDATION_FAILED);
    }
  });

  it('returns DB_QUERY_FAILED when D1 throws an error', async () => {
    const db = createQueryFakeDb(() => Promise.reject(new Error('SQLITE_BUSY')));
    const statement = createStatement('SELECT id, name, age FROM users');

    const listResult = await query(db, statement, userRowSchema);
    expect(isErr(listResult)).toBe(true);
    if (isErr(listResult)) {
      expect(listResult.error.code).toBe(DB_ERROR_CODES.DB_QUERY_FAILED);
      expect(listResult.error.message).toContain('SQLITE_BUSY');
      expect(listResult.error.details).toEqual({ sql: statement.sql });
    }

    const firstResult = await queryFirst(db, statement, userRowSchema);
    expect(isErr(firstResult)).toBe(true);
    if (isErr(firstResult)) {
      expect(firstResult.error.code).toBe(DB_ERROR_CODES.DB_QUERY_FAILED);
    }
  });
});
