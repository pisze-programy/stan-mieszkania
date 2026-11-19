import { spawn } from 'node:child_process';
import { realpath, rm } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { startLiveTestServer } from './live-test-server-runner';
import {
  EXIT_CODE_FAILURE,
  IOS_SIMULATOR_DESTINATION,
  IOS_TOOL_PATHS,
  LIVE_WORKER_ENV_VAR,
  TEMP_DERIVED_DATA_PATH,
} from './verify-fullstack.constants';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const BACKEND_DIR = path.resolve(SCRIPT_DIR, '..');
const REPO_ROOT = path.resolve(BACKEND_DIR, '..');
const OPENAPI_CONTRACT_PATH = path.join(REPO_ROOT, 'contracts', 'openapi.yaml');
const IOS_OPENAPI_SYMLINK_PATH = path.join(
  REPO_ROOT,
  'ios',
  'Packages',
  'Core',
  'Sources',
  'APIClient',
  'openapi.yaml',
);

interface StepSpec {
  readonly label: string;
  readonly command: string;
  readonly args: readonly string[];
  readonly cwd: string;
  readonly env?: NodeJS.ProcessEnv;
}

function logStep(message: string): void {
  process.stdout.write(`\n[verify:fullstack] ${message}\n`);
}

function runCommand(spec: StepSpec): Promise<void> {
  logStep(`${spec.label}: ${spec.command} ${spec.args.join(' ')}`);
  return new Promise((resolve, reject) => {
    const child = spawn(spec.command, [...spec.args], {
      cwd: spec.cwd,
      env: spec.env ?? process.env,
      stdio: 'inherit',
    });
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`${spec.label} failed with exit code ${String(code ?? EXIT_CODE_FAILURE)}`));
    });
  });
}

async function verifyOpenApiSymlink(): Promise<void> {
  const [contractRealPath, iosRealPath] = await Promise.all([
    realpath(OPENAPI_CONTRACT_PATH),
    realpath(IOS_OPENAPI_SYMLINK_PATH),
  ]);
  if (contractRealPath !== iosRealPath) {
    throw new Error(`iOS OpenAPI link points to ${iosRealPath} instead of ${contractRealPath}`);
  }
}

async function runLiveSwiftRoundtrip(): Promise<void> {
  logStep('Starting ephemeral Miniflare 5 local HTTP Worker');
  const server = await startLiveTestServer(BACKEND_DIR);
  try {
    await runCommand({
      label: 'Live Swift-to-Worker TCP roundtrip',
      command: IOS_TOOL_PATHS.SWIFT,
      args: ['test', '--package-path', 'ios/Packages/Core', '--filter', 'LiveWorkerRoundtripTests'],
      cwd: REPO_ROOT,
      env: { ...process.env, [LIVE_WORKER_ENV_VAR]: server.baseUrl },
    });
  } finally {
    await server.stop();
  }
}

async function runXcodeAppTests(): Promise<void> {
  try {
    await runCommand({
      label: 'iOS App simulator tests',
      command: IOS_TOOL_PATHS.XCODEBUILD,
      args: [
        'test',
        '-project',
        'ios/StanMieszkania.xcodeproj',
        '-scheme',
        'StanMieszkania',
        '-destination',
        IOS_SIMULATOR_DESTINATION,
        '-derivedDataPath',
        TEMP_DERIVED_DATA_PATH,
        'ARCHS=arm64',
        'ONLY_ACTIVE_ARCH=YES',
        '-skipMacroValidation',
        '-skipPackagePluginValidation',
      ],
      cwd: REPO_ROOT,
    });
  } finally {
    await rm(TEMP_DERIVED_DATA_PATH, { recursive: true, force: true });
  }
}

function buildBackendSteps(): readonly StepSpec[] {
  return [
    {
      label: 'Regenerate OpenAPI contract',
      command: 'pnpm',
      args: ['openapi:generate'],
      cwd: BACKEND_DIR,
    },
    {
      label: 'Regenerate Swift constants',
      command: 'pnpm',
      args: ['swift-constants:generate'],
      cwd: BACKEND_DIR,
    },
    {
      label: 'Verify zero contract drift',
      command: 'git',
      args: [
        'diff',
        '--exit-code',
        '--',
        'contracts/openapi.yaml',
        'ios/Packages/Core/Sources/Domain/Generated',
      ],
      cwd: REPO_ROOT,
    },
    { label: 'Backend format check', command: 'pnpm', args: ['format:check'], cwd: BACKEND_DIR },
    { label: 'Backend typecheck', command: 'pnpm', args: ['typecheck'], cwd: BACKEND_DIR },
    { label: 'Backend lint', command: 'pnpm', args: ['lint'], cwd: BACKEND_DIR },
    { label: 'Backend test suite', command: 'pnpm', args: ['test'], cwd: BACKEND_DIR },
    {
      label: 'Backend deploy dry-run',
      command: 'pnpm',
      args: ['deploy:dry-run'],
      cwd: BACKEND_DIR,
    },
  ];
}

function buildIosSteps(): readonly StepSpec[] {
  return [
    {
      label: 'iOS SwiftLint strict',
      command: IOS_TOOL_PATHS.SWIFTLINT,
      args: ['lint', '--config', 'ios/.swiftlint.yml', '--strict', 'ios'],
      cwd: REPO_ROOT,
    },
    {
      label: 'iOS swift-format strict',
      command: IOS_TOOL_PATHS.XCRUN,
      args: [
        'swift-format',
        'lint',
        '--configuration',
        'ios/.swift-format',
        '--strict',
        '--recursive',
        'ios',
      ],
      cwd: REPO_ROOT,
    },
    {
      label: 'iOS Core package tests',
      command: IOS_TOOL_PATHS.SWIFT,
      args: ['test', '--package-path', 'ios/Packages/Core'],
      cwd: REPO_ROOT,
    },
    {
      label: 'iOS Features package tests',
      command: IOS_TOOL_PATHS.SWIFT,
      args: ['test', '--package-path', 'ios/Packages/Features'],
      cwd: REPO_ROOT,
    },
  ];
}

async function main(): Promise<void> {
  for (const step of buildBackendSteps()) {
    await runCommand(step);
  }
  await verifyOpenApiSymlink();
  await runLiveSwiftRoundtrip();
  for (const step of buildIosSteps()) {
    await runCommand(step);
  }
  await runXcodeAppTests();
  logStep('All fullstack verification checks passed.');
}

await main();
