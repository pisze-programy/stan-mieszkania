import { describe, expect, it } from 'vitest';
import { createStatement, type SqlParam } from './statement';

describe('createStatement', () => {
  it('creates an immutable SQL statement with default empty params', () => {
    const statement = createStatement('SELECT 1');

    expect(statement).toEqual({ sql: 'SELECT 1', params: [] });
    expect(Object.isFrozen(statement)).toBe(true);
    expect(Object.isFrozen(statement.params)).toBe(true);
  });

  it('copies and freezes all supported SQL parameter types', () => {
    const bytes = new Uint8Array([1, 2, 3]);
    const inputParams: SqlParam[] = ['abc', 42, bytes, null];
    const statement = createStatement('INSERT INTO t VALUES (?, ?, ?, ?)', inputParams);

    inputParams.push('extra');

    expect(statement.sql).toBe('INSERT INTO t VALUES (?, ?, ?, ?)');
    expect(statement.params).toEqual(['abc', 42, bytes, null]);
    expect(Object.isFrozen(statement.params)).toBe(true);
  });
});
