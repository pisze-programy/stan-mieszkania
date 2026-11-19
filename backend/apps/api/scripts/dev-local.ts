import { spawn } from 'node:child_process';
import { access, copyFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const API_DIR = path.resolve(SCRIPT_DIR, '..');
const DEV_VARS_PATH = path.join(API_DIR, '.dev.vars');
const DEV_VARS_EXAMPLE_PATH = path.join(API_DIR, '.dev.vars.example');
const LOCAL_HOST = '127.0.0.1';
const DEFAULT_LOCAL_PORT = '8788';
const D1_BINDING_NAME = 'DB';
const EXIT_CODE_FAILURE = 1;

async function ensureDevVarsFile(): Promise<void> {
  try {
    await access(DEV_VARS_PATH);
  } catch {
    await copyFile(DEV_VARS_EXAMPLE_PATH, DEV_VARS_PATH);
    process.stdout.write('[dev] Created backend/apps/api/.dev.vars from .dev.vars.example\n');
  }
}

function runPnpmExec(args: readonly string[]): Promise<number> {
  return new Promise((resolve, reject) => {
    const child = spawn('pnpm', ['exec', ...args], {
      cwd: API_DIR,
      env: process.env,
      stdio: 'inherit',
    });

    const forwardSignal = (signal: NodeJS.Signals): void => {
      if (child.exitCode === null) {
        child.kill(signal);
      }
    };

    process.on('SIGINT', forwardSignal);
    process.on('SIGTERM', forwardSignal);

    child.on('error', (error) => {
      process.off('SIGINT', forwardSignal);
      process.off('SIGTERM', forwardSignal);
      reject(error);
    });

    child.on('close', (code) => {
      process.off('SIGINT', forwardSignal);
      process.off('SIGTERM', forwardSignal);
      resolve(code ?? EXIT_CODE_FAILURE);
    });
  });
}

async function main(): Promise<void> {
  await ensureDevVarsFile();

  const migrateExit = await runPnpmExec([
    'wrangler',
    'd1',
    'migrations',
    'apply',
    D1_BINDING_NAME,
    '--local',
    '--force',
  ]);
  if (migrateExit !== 0) {
    process.exit(migrateExit);
  }

  const port = process.env.PORT ?? DEFAULT_LOCAL_PORT;
  const devExit = await runPnpmExec([
    'wrangler',
    'dev',
    '--local',
    '--ip',
    LOCAL_HOST,
    '--port',
    port,
  ]);
  process.exit(devExit);
}

await main();
