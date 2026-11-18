import type { D1Database, D1DatabaseSession, D1Meta, D1Result } from '@cloudflare/workers-types';
import { isErr, isOk } from '@stanmieszkania/shared';
import { describe, expect, expectTypeOf, it, vi } from 'vitest';
import { executeBatch } from './batch';
import { DB_ERROR_CODES } from './db.errors';
import { createStatement, type D1Client, type D1PreparedStatementLike } from './statement';

const DEFAULT_META: D1Meta & Record<string, unknown> = {
  duration: 1,
  size_after: 0,
  rows_read: 0,
  rows_written: 1,
  last_row_id: 1,
  changed_db: true,
  changes: 1,
};

const unsupported = (): Promise<never> => Promise.reject(new Error('Unexpected D1 call'));

interface RecordedStatement {
  readonly sql: string;
  readonly params: readonly unknown[];
}

interface FakeBatchStatement extends D1PreparedStatementLike<FakeBatchStatement> {
  toRecorded(): RecordedStatement;
}

function createBatchFakeDb(
  onBatch: (statements: readonly RecordedStatement[]) => Promise<D1Result[]>,
): { readonly db: D1Client<FakeBatchStatement>; readonly batchSpy: ReturnType<typeof vi.fn> } {
  const batchSpy = vi.fn(async (preparedStatements: FakeBatchStatement[]) =>
    onBatch(preparedStatements.map((stmt) => stmt.toRecorded())),
  );

  const db: D1Client<FakeBatchStatement> = {
    prepare(sql: string): FakeBatchStatement {
      let boundParams: readonly unknown[] = [];
      const statement: FakeBatchStatement = {
        bind(...values: unknown[]): FakeBatchStatement {
          boundParams = values;
          return statement;
        },
        toRecorded: (): RecordedStatement => ({ sql, params: boundParams }),
        all: unsupported,
        run: unsupported,
      };
      return statement;
    },
    // reason: D1Client.batch<T> is method-generic and cannot be typed without assertion on a Vitest spy.
    batch: batchSpy as unknown as D1Client<FakeBatchStatement>['batch'],
  };

  return { db, batchSpy };
}

describe('executeBatch', () => {
  it('accepts Cloudflare D1Database and D1DatabaseSession types', () => {
    expectTypeOf<D1Database>().toExtend<D1Client>();
    expectTypeOf<D1DatabaseSession>().toExtend<D1Client>();
  });

  it('returns an empty array without invoking db.batch for an empty statement list', async () => {
    const { db, batchSpy } = createBatchFakeDb(() => Promise.resolve([]));

    const result = await executeBatch(db, []);

    expect(result).toEqual({ ok: true, value: [] });
    expect(batchSpy).not.toHaveBeenCalled();
  });

  it('prepares, binds, and executes statements atomically in order', async () => {
    const received: RecordedStatement[] = [];
    const expectedResults: D1Result[] = [
      { success: true, meta: DEFAULT_META, results: [] },
      { success: true, meta: { ...DEFAULT_META, last_row_id: 2 }, results: [] },
    ];

    const { db, batchSpy } = createBatchFakeDb((statements) => {
      received.push(...statements);
      return Promise.resolve(expectedResults);
    });

    const result = await executeBatch(db, [
      createStatement('INSERT INTO media (id) VALUES (?)', ['m1']),
      createStatement('INSERT INTO change_log (entity_id) VALUES (?)', ['m1']),
    ]);

    expect(batchSpy).toHaveBeenCalledTimes(1);
    expect(received).toEqual([
      { sql: 'INSERT INTO media (id) VALUES (?)', params: ['m1'] },
      { sql: 'INSERT INTO change_log (entity_id) VALUES (?)', params: ['m1'] },
    ]);
    expect(isOk(result)).toBe(true);
    if (isOk(result)) {
      expect(result.value).toEqual(expectedResults);
    }
  });

  it('returns DB_BATCH_FAILED when db.batch throws', async () => {
    const { db } = createBatchFakeDb(() =>
      Promise.reject(new Error('FOREIGN KEY constraint failed')),
    );

    const result = await executeBatch(db, [
      createStatement('INSERT INTO entries (id, media_id) VALUES (?, ?)', ['e1', 'missing']),
    ]);

    expect(isErr(result)).toBe(true);
    if (isErr(result)) {
      expect(result.error.code).toBe(DB_ERROR_CODES.DB_BATCH_FAILED);
      expect(result.error.message).toContain('FOREIGN KEY constraint failed');
      expect(result.error.details).toEqual({ statementCount: 1 });
    }
  });
});
