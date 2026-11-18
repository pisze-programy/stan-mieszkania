import type { D1PreparedStatement, D1Result } from '@cloudflare/workers-types';

export type SqlParam = string | number | Uint8Array | null;

export interface SqlStatement {
  readonly sql: string;
  readonly params: readonly SqlParam[];
}

export interface D1PreparedStatementLike<TSelf = unknown> {
  bind(...values: unknown[]): TSelf;
  all<T = Record<string, unknown>>(): Promise<D1Result<T>>;
  run<T = Record<string, unknown>>(): Promise<D1Result<T>>;
}

export interface D1Queryable {
  prepare(query: string): D1PreparedStatementLike<D1PreparedStatementLike>;
}

export interface D1Client<
  TStatement extends D1PreparedStatementLike<TStatement> = D1PreparedStatement,
> {
  prepare(query: string): TStatement;
  batch<T = unknown>(statements: TStatement[]): Promise<D1Result<T>[]>;
}

export function createStatement(sql: string, params: readonly SqlParam[] = []): SqlStatement {
  return Object.freeze({
    sql,
    params: Object.freeze([...params]),
  });
}
