import { createServer, type IncomingMessage, type ServerResponse } from 'node:http';
import type { AddressInfo } from 'node:net';
import { createApp } from '../src/app';
import { createD1TestHarness } from '../src/testing/d1-test-harness';
import { buildE2eEnv } from '../src/testing/e2e/e2e-client';

const LISTEN_HOST = '127.0.0.1';
const EPHEMERAL_PORT = 0;
const HTTP_STATUS_INTERNAL_ERROR = 500;
const READY_LINE_PREFIX = 'LIVE_WORKER_BASE_URL=';

function readRequestBody(req: IncomingMessage): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    req.on('data', (chunk: Buffer) => {
      chunks.push(chunk);
    });
    req.on('end', () => {
      resolve(Buffer.concat(chunks));
    });
    req.on('error', reject);
  });
}

function buildRequestHeaders(req: IncomingMessage): Headers {
  const headers = new Headers();
  for (const [key, value] of Object.entries(req.headers)) {
    if (typeof value === 'string') {
      headers.set(key, value);
    } else if (Array.isArray(value)) {
      for (const item of value) {
        headers.append(key, item);
      }
    }
  }
  return headers;
}

async function toWebRequest(req: IncomingMessage, baseUrl: string): Promise<Request> {
  const method = req.method ?? 'GET';
  const url = new URL(req.url ?? '/', baseUrl);
  const headers = buildRequestHeaders(req);

  if (method === 'GET' || method === 'HEAD') {
    return new Request(url, { method, headers });
  }

  const bodyBuffer = await readRequestBody(req);
  const bodyBytes = new Uint8Array(bodyBuffer.byteLength);
  bodyBytes.set(bodyBuffer);
  return new Request(url, { method, headers, body: bodyBytes });
}

async function writeWebResponse(response: Response, res: ServerResponse): Promise<void> {
  res.statusCode = response.status;
  response.headers.forEach((value, key) => {
    res.setHeader(key, value);
  });
  const payload = Buffer.from(await response.arrayBuffer());
  res.end(payload);
}

async function main(): Promise<void> {
  const harness = await createD1TestHarness();
  const app = createApp();
  const workerEnv = buildE2eEnv(harness);
  let baseUrl = `http://${LISTEN_HOST}`;

  const server = createServer((req, res) => {
    void (async () => {
      try {
        const webRequest = await toWebRequest(req, baseUrl);
        const webResponse = await app.fetch(webRequest, workerEnv);
        await writeWebResponse(webResponse, res);
      } catch (error) {
        res.statusCode = HTTP_STATUS_INTERNAL_ERROR;
        res.setHeader('Content-Type', 'text/plain; charset=utf-8');
        res.end(error instanceof Error ? error.message : 'Internal Server Error');
      }
    })();
  });

  await new Promise<void>((resolve, reject) => {
    server.once('error', reject);
    server.listen(EPHEMERAL_PORT, LISTEN_HOST, () => {
      resolve();
    });
  });

  const address = server.address();
  if (address === null || typeof address === 'string') {
    await harness.dispose();
    throw new Error('Failed to resolve listening TCP port');
  }

  const tcpAddress: AddressInfo = address;
  baseUrl = `http://${LISTEN_HOST}:${String(tcpAddress.port)}`;
  process.stdout.write(`${READY_LINE_PREFIX}${baseUrl}\n`);

  let shuttingDown = false;
  const shutdown = (): void => {
    if (shuttingDown) {
      return;
    }
    shuttingDown = true;
    server.close(() => {
      void harness.dispose().finally(() => {
        process.exit(0);
      });
    });
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

await main();
