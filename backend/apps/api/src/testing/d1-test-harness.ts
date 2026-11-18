import { readdir, readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Miniflare } from 'miniflare';

const D1_BINDING_NAME = 'DB';
const R2_BINDING_NAME = 'MEDIA_BUCKET';
const USER_GUARD_BINDING_NAME = 'USER_GUARD';
const USER_GUARD_CLASS_NAME = 'UserGuard';
const TEST_WORKER_NAME = 'stanmieszkania-test-worker';
const COMPATIBILITY_DATE = '2026-10-01';
const CURRENT_DIR = path.dirname(fileURLToPath(import.meta.url));
const MIGRATIONS_DIR = path.resolve(CURRENT_DIR, '../../migrations');
const DURABLE_OBJECTS_DIR = path.resolve(CURRENT_DIR, '../durable-objects');
const WORKER_ENTRY_SCRIPT =
  "export { UserGuard } from './user-guard.durable-object.js';\n" +
  'export default { fetch() { return new Response("ok"); } };';

export type MiniflareD1Database = Awaited<ReturnType<Miniflare['getD1Database']>>;
export type MiniflareR2Bucket = Awaited<ReturnType<Miniflare['getR2Bucket']>>;
export type MiniflareDurableObjectNamespace = Awaited<
  ReturnType<Miniflare['getDurableObjectNamespace']>
>;

export interface D1TestHarness {
  readonly db: MiniflareD1Database;
  readonly r2: MiniflareR2Bucket;
  readonly userGuard: MiniflareDurableObjectNamespace;
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

async function loadUserGuardModules(): Promise<{
  readonly constantsJs: string;
  readonly userGuardJs: string;
}> {
  const [constantsTs, userGuardTs] = await Promise.all([
    readFile(path.join(DURABLE_OBJECTS_DIR, 'user-guard.constants.ts'), 'utf8'),
    readFile(path.join(DURABLE_OBJECTS_DIR, 'user-guard.durable-object.ts'), 'utf8'),
  ]);

  const constantsJs = stripTypeScriptTypes(constantsTs);
  const userGuardJs = stripTypeScriptTypes(userGuardTs).replace(
    "'./user-guard.constants'",
    "'./user-guard.constants.js'",
  );

  return { constantsJs, userGuardJs };
}

export async function createD1TestHarness(): Promise<D1TestHarness> {
  const { constantsJs, userGuardJs } = await loadUserGuardModules();

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
                contents: WORKER_ENTRY_SCRIPT,
              },
              'user-guard.constants.js': {
                type: 'esm',
                contents: constantsJs,
              },
              'user-guard.durable-object.js': {
                type: 'esm',
                contents: userGuardJs,
              },
            },
          },
          exports: {
            [USER_GUARD_CLASS_NAME]: {
              type: 'durable-object',
              storage: 'sqlite',
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
            [USER_GUARD_BINDING_NAME]: {
              type: 'durable-object',
              worker: TEST_WORKER_NAME,
              exportName: USER_GUARD_CLASS_NAME,
            },
          },
        },
      },
    ],
  });

  try {
    const db = await mf.getD1Database(D1_BINDING_NAME);
    const r2 = await mf.getR2Bucket(R2_BINDING_NAME);
    const userGuard = await mf.getDurableObjectNamespace(USER_GUARD_BINDING_NAME);
    const appliedMigrations = await applySqlMigrations(db, MIGRATIONS_DIR);

    return {
      db,
      r2,
      userGuard,
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
