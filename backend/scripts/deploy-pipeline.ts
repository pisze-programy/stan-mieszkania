import { mkdir, readdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import {
  DEPLOY_BOOKMARKS_DIR_NAME,
  DEPLOY_STEP_NAMES,
  DESTRUCTIVE_SQL_PATTERNS,
  JSON_INDENT_SPACES,
  PRODUCTION_D1_DATABASE_NAME,
  PRODUCTION_WRANGLER_ENV,
} from './deploy.constants';

export interface CommandInvocation {
  readonly command: string;
  readonly args: readonly string[];
  readonly cwd: string;
}

export interface CommandExecutionResult {
  readonly exitCode: number;
  readonly stdout: string;
  readonly stderr: string;
}

export type CommandRunner = (invocation: CommandInvocation) => Promise<CommandExecutionResult>;

export interface DeployPipelineOptions {
  readonly backendDir: string;
  readonly apiDir: string;
  readonly migrationsDir: string;
  readonly dryRun: boolean;
  readonly databaseName?: string;
  readonly wranglerEnv?: string;
  readonly allowDestructiveMigrations?: readonly string[];
  readonly nowIso?: () => string;
  readonly runner: CommandRunner;
  readonly log: (message: string) => void;
}

export interface DestructiveMigrationViolation {
  readonly fileName: string;
  readonly statementKind: string;
}

export interface DeployPipelineOutcome {
  readonly dryRun: boolean;
  readonly executedSteps: readonly string[];
  readonly plannedSteps: readonly string[];
  readonly bookmarkPath: string | null;
}

function stripSqlComments(sql: string): string {
  return sql.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/--[^\n]*/g, ' ');
}

// Architecture 8: Expand -> contract migrations must be additive unless explicitly whitelisted.
export async function checkAdditiveMigrations(
  migrationsDir: string,
  allowedDestructiveFiles: readonly string[] = [],
): Promise<readonly DestructiveMigrationViolation[]> {
  const allowed = new Set(allowedDestructiveFiles);
  const entries = (await readdir(migrationsDir)).filter((name) => name.endsWith('.sql')).sort();
  const violations: DestructiveMigrationViolation[] = [];

  for (const fileName of entries) {
    if (allowed.has(fileName)) {
      continue;
    }
    const rawSql = await readFile(path.join(migrationsDir, fileName), 'utf8');
    const cleanSql = stripSqlComments(rawSql);
    for (const pattern of DESTRUCTIVE_SQL_PATTERNS) {
      if (pattern.regex.test(cleanSql)) {
        violations.push({ fileName, statementKind: pattern.label });
      }
    }
  }

  return violations;
}

function parseOptionalJson(text: string): unknown {
  const trimmed = text.trim();
  if (trimmed.length === 0) return null;
  try {
    return JSON.parse(trimmed);
  } catch {
    return null;
  }
}

async function runRequiredStep(
  stepName: string,
  invocation: CommandInvocation,
  runner: CommandRunner,
  executedSteps: string[],
  log: (message: string) => void,
): Promise<CommandExecutionResult> {
  log(`[deploy] running ${stepName}: ${invocation.command} ${invocation.args.join(' ')}`);
  const result = await runner(invocation);
  if (result.exitCode !== 0) {
    const details = result.stderr.trim() || result.stdout.trim();
    throw new Error(
      `Deploy step "${stepName}" failed with exit code ${String(result.exitCode)}${details.length > 0 ? `: ${details}` : ''}`,
    );
  }
  executedSteps.push(stepName);
  return result;
}

// Architecture 8: Enforce quality gates, additive migration check, D1 Time Travel bookmark, migrate, then deploy.
export async function runDeployPipeline(
  options: DeployPipelineOptions,
): Promise<DeployPipelineOutcome> {
  const databaseName = options.databaseName ?? PRODUCTION_D1_DATABASE_NAME;
  const wranglerEnv = options.wranglerEnv ?? PRODUCTION_WRANGLER_ENV;
  const nowIso = options.nowIso ?? (() => new Date().toISOString());
  const executedSteps: string[] = [];

  const gateSteps: readonly (readonly [string, string])[] = [
    [DEPLOY_STEP_NAMES.FORMAT_CHECK, 'format:check'],
    [DEPLOY_STEP_NAMES.TYPECHECK, 'typecheck'],
    [DEPLOY_STEP_NAMES.LINT, 'lint'],
    [DEPLOY_STEP_NAMES.TEST, 'test'],
  ];
  for (const [step, script] of gateSteps) {
    await runRequiredStep(
      step,
      { command: 'pnpm', args: [script], cwd: options.backendDir },
      options.runner,
      executedSteps,
      options.log,
    );
  }

  options.log(`[deploy] running ${DEPLOY_STEP_NAMES.MIGRATION_SAFETY_CHECK}`);
  const violations = await checkAdditiveMigrations(
    options.migrationsDir,
    options.allowDestructiveMigrations,
  );
  if (violations.length > 0) {
    const summary = violations.map((v) => `${v.fileName} (${v.statementKind})`).join(', ');
    throw new Error(`Destructive SQL migrations blocked by additive policy: ${summary}`);
  }
  executedSteps.push(DEPLOY_STEP_NAMES.MIGRATION_SAFETY_CHECK);

  const timeTravelArgs = [
    'wrangler',
    'd1',
    'time-travel',
    'info',
    databaseName,
    '--env',
    wranglerEnv,
    '--json',
  ];
  const migrateArgs = [
    'wrangler',
    'd1',
    'migrations',
    'apply',
    databaseName,
    '--remote',
    '--env',
    wranglerEnv,
  ];
  const deployArgs = ['wrangler', 'deploy', '--env', wranglerEnv];

  if (options.dryRun) {
    const plannedSteps = [
      `pnpm exec ${timeTravelArgs.join(' ')}`,
      `pnpm exec ${migrateArgs.join(' ')}`,
      `pnpm exec ${deployArgs.join(' ')}`,
    ];
    for (const planned of plannedSteps) {
      options.log(`[deploy:dry-run] planned: ${planned}`);
    }
    return { dryRun: true, executedSteps, plannedSteps, bookmarkPath: null };
  }

  const bookmarkResult = await runRequiredStep(
    DEPLOY_STEP_NAMES.TIME_TRAVEL_BOOKMARK,
    { command: 'pnpm', args: ['exec', ...timeTravelArgs], cwd: options.apiDir },
    options.runner,
    executedSteps,
    options.log,
  );

  const capturedAt = nowIso();
  const safeTimestamp = capturedAt.replace(/[:.]/g, '-');
  const bookmarksDir = path.join(options.backendDir, DEPLOY_BOOKMARKS_DIR_NAME);
  await mkdir(bookmarksDir, { recursive: true });
  const bookmarkPath = path.join(bookmarksDir, `d1-${databaseName}-${safeTimestamp}.json`);
  const recoveryRecord = {
    capturedAt,
    databaseName,
    environment: wranglerEnv,
    bookmark: parseOptionalJson(bookmarkResult.stdout),
    rawOutput: bookmarkResult.stdout.trim(),
  };
  await writeFile(
    bookmarkPath,
    `${JSON.stringify(recoveryRecord, null, JSON_INDENT_SPACES)}\n`,
    'utf8',
  );
  options.log(`[deploy] saved D1 Time Travel bookmark to ${bookmarkPath}`);

  await runRequiredStep(
    DEPLOY_STEP_NAMES.D1_MIGRATIONS_APPLY,
    { command: 'pnpm', args: ['exec', ...migrateArgs], cwd: options.apiDir },
    options.runner,
    executedSteps,
    options.log,
  );

  await runRequiredStep(
    DEPLOY_STEP_NAMES.WORKER_DEPLOY,
    { command: 'pnpm', args: ['exec', ...deployArgs], cwd: options.apiDir },
    options.runner,
    executedSteps,
    options.log,
  );

  return { dryRun: false, executedSteps, plannedSteps: [], bookmarkPath };
}
