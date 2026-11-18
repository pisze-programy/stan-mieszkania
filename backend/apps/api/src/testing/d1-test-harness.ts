import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Miniflare } from 'miniflare';

const D1_BINDING_NAME = 'DB';
const R2_BINDING_NAME = 'MEDIA_BUCKET';
const TEST_WORKER_NAME = 'stanmieszkania-test-worker';
const COMPATIBILITY_DATE = '2026-10-01';
const MIGRATIONS_DIR = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../migrations',
);
const NOOP_WORKER_SCRIPT = 'export default { fetch() { return new Response("ok"); } };';

export type MiniflareD1Database = Awaited<ReturnType<Miniflare['getD1Database']>>;
export type MiniflareR2Bucket = Awaited<ReturnType<Miniflare['getR2Bucket']>>;

export interface D1TestHarness {
  readonly db: MiniflareD1Database;
  readonly r2: MiniflareR2Bucket;
  readonly appliedMigrations: readonly string[];
  readonly dispose: () => Promise<void>;
}

function splitSqlStatements(sql: string): readonly string[] {
  const statements: string[] = [];
  let buffer = '';
  let inSingleQuote = false;
  let inLineComment = false;

  for (let index = 0; index < sql.length; index += 1) {
    const char = sql[index] ?? '';
    const nextChar = sql[index + 1] ?? '';

    if (inLineComment) {
      if (char === '\n') {
        inLineComment = false;
        buffer += char;
      }
      continue;
    }

    if (!inSingleQuote && char === '-' && nextChar === '-') {
      inLineComment = true;
      index += 1;
      continue;
    }

    if (char === "'") {
      buffer += char;
      if (inSingleQuote && nextChar === "'") {
        buffer += nextChar;
        index += 1;
      } else {
        inSingleQuote = !inSingleQuote;
      }
      continue;
    }

    if (!inSingleQuote && char === ';') {
      const trimmed = buffer.trim();
      if (trimmed.length > 0) {
        statements.push(trimmed);
      }
      buffer = '';
      continue;
    }

    buffer += char;
  }

  const remainder = buffer.trim();
  if (remainder.length > 0) {
    statements.push(remainder);
  }
  return statements;
}

async function applySqlMigrations(
  db: MiniflareD1Database,
  migrationsDir: string,
): Promise<readonly string[]> {
  const entries = await readdir(migrationsDir);
  const sqlFiles = entries.filter((entry) => entry.endsWith('.sql')).sort();

  for (const fileName of sqlFiles) {
    const filePath = path.join(migrationsDir, fileName);
    const sql = await readFile(filePath, 'utf8');
    const statements = splitSqlStatements(sql);
    if (statements.length > 0) {
      await db.batch(statements.map((statement) => db.prepare(statement)));
    }
  }

  return sqlFiles;
}

export async function createD1TestHarness(): Promise<D1TestHarness> {
  const mf = new Miniflare({
    workers: [
      {
        config: {
          name: TEST_WORKER_NAME,
          compatibilityDate: COMPATIBILITY_DATE,
          manifest: {
            mainModule: 'index.js',
            modules: {
              'index.js': {
                type: 'esm',
                contents: NOOP_WORKER_SCRIPT,
              },
            },
          },
          env: {
            [D1_BINDING_NAME]: {
              type: 'd1',
              id: 'stanmieszkania-test-db',
            },
            [R2_BINDING_NAME]: {
              type: 'r2',
              name: 'stanmieszkania-test-media',
            },
          },
        },
      },
    ],
  });

  try {
    const db = await mf.getD1Database(D1_BINDING_NAME);
    const r2 = await mf.getR2Bucket(R2_BINDING_NAME);
    const appliedMigrations = await applySqlMigrations(db, MIGRATIONS_DIR);

    return {
      db,
      r2,
      appliedMigrations,
      dispose: async (): Promise<void> => {
        await mf.dispose();
      },
    };
  } catch (error: unknown) {
    await mf.dispose();
    throw error;
  }
}
