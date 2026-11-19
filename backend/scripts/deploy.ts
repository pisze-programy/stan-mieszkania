import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { CLI_ARGS_START_INDEX } from './deploy.constants';
import {
  runDeployPipeline,
  type CommandExecutionResult,
  type CommandInvocation,
} from './deploy-pipeline';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const BACKEND_DIR = path.resolve(SCRIPT_DIR, '..');
const API_DIR = path.join(BACKEND_DIR, 'apps', 'api');
const MIGRATIONS_DIR = path.join(API_DIR, 'migrations');

function spawnCommand(invocation: CommandInvocation): Promise<CommandExecutionResult> {
  return new Promise((resolve, reject) => {
    const child = spawn(invocation.command, [...invocation.args], {
      cwd: invocation.cwd,
      env: process.env,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (chunk: Buffer) => {
      stdout += chunk.toString('utf8');
    });
    child.stderr.on('data', (chunk: Buffer) => {
      stderr += chunk.toString('utf8');
    });
    child.on('error', reject);
    child.on('close', (code) => {
      resolve({ exitCode: code ?? 1, stdout, stderr });
    });
  });
}

function parseAllowDestructiveArgs(argv: readonly string[]): readonly string[] {
  const prefix = '--allow-destructive=';
  const allowed: string[] = [];
  for (const arg of argv) {
    if (arg.startsWith(prefix)) {
      const value = arg.slice(prefix.length).trim();
      if (value.length > 0) {
        allowed.push(...value.split(',').map((item) => item.trim()));
      }
    }
  }
  return allowed;
}

async function main(): Promise<void> {
  const argv = process.argv.slice(CLI_ARGS_START_INDEX);
  const dryRun = argv.includes('--dry-run');
  const allowDestructiveMigrations = parseAllowDestructiveArgs(argv);

  await runDeployPipeline({
    backendDir: BACKEND_DIR,
    apiDir: API_DIR,
    migrationsDir: MIGRATIONS_DIR,
    dryRun,
    allowDestructiveMigrations,
    runner: spawnCommand,
    log: (message) => {
      process.stdout.write(`${message}\n`);
    },
  });
}

await main();
