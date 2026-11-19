import { spawn, type ChildProcess } from 'node:child_process';
import {
  EXIT_CODE_FAILURE,
  FULLSTACK_TIMEOUTS_MS,
  LIVE_SERVER_READY_PREFIX,
} from './verify-fullstack.constants';

export interface RunningLiveTestServer {
  readonly baseUrl: string;
  readonly stop: () => Promise<void>;
}

export async function startLiveTestServer(backendDir: string): Promise<RunningLiveTestServer> {
  const child: ChildProcess = spawn(
    'pnpm',
    ['--filter', '@stanmieszkania/api', 'exec', 'tsx', 'scripts/start-live-test-server.ts'],
    {
      cwd: backendDir,
      env: process.env,
      stdio: ['ignore', 'pipe', 'pipe'],
    },
  );

  const baseUrl = await new Promise<string>((resolve, reject) => {
    let stdoutBuffer = '';
    let stderrBuffer = '';

    const timer = setTimeout(() => {
      child.kill('SIGTERM');
      reject(
        new Error(`Timed out waiting for live test server startup. stderr: ${stderrBuffer.trim()}`),
      );
    }, FULLSTACK_TIMEOUTS_MS.SERVER_STARTUP);

    child.stdout?.on('data', (chunk: Buffer) => {
      stdoutBuffer += chunk.toString('utf8');
      for (const line of stdoutBuffer.split('\n')) {
        if (line.startsWith(LIVE_SERVER_READY_PREFIX)) {
          clearTimeout(timer);
          resolve(line.slice(LIVE_SERVER_READY_PREFIX.length).trim());
          return;
        }
      }
    });

    child.stderr?.on('data', (chunk: Buffer) => {
      stderrBuffer += chunk.toString('utf8');
    });

    child.once('error', (error) => {
      clearTimeout(timer);
      reject(error);
    });

    child.once('close', (code) => {
      clearTimeout(timer);
      reject(
        new Error(
          `Live test server exited before ready (code=${String(code ?? EXIT_CODE_FAILURE)}): ${stderrBuffer.trim()}`,
        ),
      );
    });
  });

  const stop = (): Promise<void> =>
    new Promise((resolve) => {
      if (child.exitCode !== null) {
        resolve();
        return;
      }
      const killTimer = setTimeout(() => {
        child.kill('SIGKILL');
      }, FULLSTACK_TIMEOUTS_MS.SERVER_SHUTDOWN);
      child.once('close', () => {
        clearTimeout(killTimer);
        resolve();
      });
      child.kill('SIGTERM');
    });

  return { baseUrl, stop };
}
