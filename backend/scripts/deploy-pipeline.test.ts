import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { DEPLOY_STEP_NAMES } from './deploy.constants';
import {
  checkAdditiveMigrations,
  runDeployPipeline,
  type CommandInvocation,
} from './deploy-pipeline';

describe('Production deploy pipeline', () => {
  const tempDirs: string[] = [];

  const makeTempWorkspace = async (migrations: Record<string, string>) => {
    const dir = await mkdtemp(path.join(os.tmpdir(), 'stanmieszkania-deploy-'));
    tempDirs.push(dir);
    for (const [name, sql] of Object.entries(migrations)) {
      await writeFile(path.join(dir, name), sql, 'utf8');
    }
    return dir;
  };

  afterEach(async () => {
    while (tempDirs.length > 0) {
      const dir = tempDirs.pop();
      if (dir !== undefined) {
        await rm(dir, { recursive: true, force: true });
      }
    }
  });

  it('executes steps 1-8 in order and writes D1 Time Travel bookmark before applying migrations', async () => {
    const dir = await makeTempWorkspace({
      '0001_init.sql': 'CREATE TABLE t (id TEXT PRIMARY KEY);\n-- DROP TABLE safe_in_comment;',
    });
    const invoked: CommandInvocation[] = [];
    let bookmarkExistedBeforeMigrate = false;

    const outcome = await runDeployPipeline({
      backendDir: dir,
      apiDir: dir,
      migrationsDir: dir,
      dryRun: false,
      nowIso: () => '2026-11-19T12:00:00.000Z',
      runner: async (inv) => {
        invoked.push(inv);
        if (inv.args.includes('time-travel')) {
          return {
            exitCode: 0,
            stdout: JSON.stringify({ bookmark: '00000042-00000001-00004abc' }),
            stderr: '',
          };
        }
        if (inv.args.includes('migrations')) {
          const expectedBookmark = path.join(
            dir,
            '.deploy-bookmarks',
            'd1-stanmieszkania-production-2026-11-19T12-00-00-000Z.json',
          );
          const content = await readFile(expectedBookmark, 'utf8');
          bookmarkExistedBeforeMigrate = content.includes('00000042-00000001-00004abc');
        }
        return { exitCode: 0, stdout: 'ok', stderr: '' };
      },
      log: () => undefined,
    });

    expect(outcome.dryRun).toBe(false);
    expect(outcome.executedSteps).toEqual([
      DEPLOY_STEP_NAMES.FORMAT_CHECK,
      DEPLOY_STEP_NAMES.TYPECHECK,
      DEPLOY_STEP_NAMES.LINT,
      DEPLOY_STEP_NAMES.TEST,
      DEPLOY_STEP_NAMES.MIGRATION_SAFETY_CHECK,
      DEPLOY_STEP_NAMES.TIME_TRAVEL_BOOKMARK,
      DEPLOY_STEP_NAMES.D1_MIGRATIONS_APPLY,
      DEPLOY_STEP_NAMES.WORKER_DEPLOY,
    ]);
    expect(bookmarkExistedBeforeMigrate).toBe(true);
    expect(outcome.bookmarkPath).not.toBeNull();
    expect(invoked).toHaveLength(7);
  });

  it('fails fast when tests fail and never invokes wrangler', async () => {
    const dir = await makeTempWorkspace({ '0001_init.sql': 'CREATE TABLE t (id TEXT);' });
    const invoked: string[] = [];

    await expect(
      runDeployPipeline({
        backendDir: dir,
        apiDir: dir,
        migrationsDir: dir,
        dryRun: false,
        runner: (inv) => {
          invoked.push(inv.args.join(' '));
          if (inv.args[0] === 'test') {
            return Promise.resolve({ exitCode: 1, stdout: '', stderr: 'test failed' });
          }
          return Promise.resolve({ exitCode: 0, stdout: '', stderr: '' });
        },
        log: () => undefined,
      }),
    ).rejects.toThrow(/Deploy step "test" failed/);

    expect(invoked).toEqual(['format:check', 'typecheck', 'lint', 'test']);
  });

  it('rejects destructive SQL migrations unless explicitly whitelisted and supports --dry-run', async () => {
    const dir = await makeTempWorkspace({
      '0001_init.sql': 'CREATE TABLE t (id TEXT);',
      '0002_drop.sql': 'ALTER TABLE t DROP COLUMN old_col;',
    });

    const violations = await checkAdditiveMigrations(dir);
    expect(violations).toEqual([{ fileName: '0002_drop.sql', statementKind: 'DROP COLUMN' }]);

    await expect(
      runDeployPipeline({
        backendDir: dir,
        apiDir: dir,
        migrationsDir: dir,
        dryRun: true,
        runner: () => Promise.resolve({ exitCode: 0, stdout: '', stderr: '' }),
        log: () => undefined,
      }),
    ).rejects.toThrow(/Destructive SQL migrations blocked/);

    const dryRunOutcome = await runDeployPipeline({
      backendDir: dir,
      apiDir: dir,
      migrationsDir: dir,
      dryRun: true,
      allowDestructiveMigrations: ['0002_drop.sql'],
      runner: () => Promise.resolve({ exitCode: 0, stdout: '', stderr: '' }),
      log: () => undefined,
    });
    expect(dryRunOutcome.dryRun).toBe(true);
    expect(dryRunOutcome.bookmarkPath).toBeNull();
    expect(dryRunOutcome.plannedSteps).toHaveLength(3);
  });
});
