import { MEDIA_CONTENT_TYPE_JPEG } from '../../modules/media';
import type { D1TestHarness } from '../d1-test-harness';

const E2E_BASE_URL = 'http://localhost';
const HEX_RADIX = 16;
const HEX_BYTE_WIDTH = 2;
const DEFAULT_WIDTH_PX = 800;
const DEFAULT_HEIGHT_PX = 600;
const JPEG_MAGIC_0 = 0xff;
const JPEG_MAGIC_1 = 0xd8;
const JPEG_MAGIC_2 = 0xff;
const JPEG_MAGIC_3 = 0xe0;
const FORBIDDEN_GPS_KEYS = new Set([
  'lat',
  'lng',
  'accuracyM',
  'locationSource',
  'accuracy_m',
  'location_source',
]);

export type E2eFetchFn = (request: Request) => Response | Promise<Response>;

export interface E2eRequestOptions {
  readonly method?: string;
  readonly token?: string;
  readonly json?: unknown;
  readonly body?: Uint8Array<ArrayBuffer>;
  readonly contentType?: string;
}

export interface E2eClient {
  request(path: string, options?: E2eRequestOptions): Promise<Response>;
}

export function makeJpegBytes(seedByteA: number, seedByteB: number): Uint8Array<ArrayBuffer> {
  return new Uint8Array([
    JPEG_MAGIC_0,
    JPEG_MAGIC_1,
    JPEG_MAGIC_2,
    JPEG_MAGIC_3,
    seedByteA,
    seedByteB,
  ]);
}

export function buildE2eEnv(harness: D1TestHarness, extra?: Record<string, string>) {
  return {
    DB: harness.db,
    MEDIA_BUCKET: harness.r2,
    USER_GUARD: harness.userGuard,
    APARTMENT_COORDINATOR: harness.apartmentCoordinator,
    AUTH_MODE: 'local',
    STORAGE_MODE: 'local',
    ...(extra ?? {}),
  };
}

export async function sha256Hex(bytes: Uint8Array<ArrayBuffer>): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(HEX_RADIX).padStart(HEX_BYTE_WIDTH, '0'))
    .join('');
}

export async function initMediaRaw(
  client: E2eClient,
  token: string,
  apartmentId: string,
  mediaId: string,
  bytes: Uint8Array<ArrayBuffer>,
  capturedAt: string,
): Promise<Response> {
  return client.request(`/v1/apartments/${apartmentId}/media/${mediaId}/init`, {
    method: 'POST',
    token,
    json: {
      kind: 'photo',
      source: 'camera',
      sha256: await sha256Hex(bytes),
      capturedAt,
      capturedTz: 'Europe/Warsaw',
      width: DEFAULT_WIDTH_PX,
      height: DEFAULT_HEIGHT_PX,
      bytes: bytes.byteLength,
    },
  });
}

export function assertNoGpsFields(payload: unknown): void {
  if (payload === null || typeof payload !== 'object') {
    return;
  }
  if (Array.isArray(payload)) {
    for (const item of payload) {
      assertNoGpsFields(item);
    }
    return;
  }
  for (const [key, value] of Object.entries(payload)) {
    if (FORBIDDEN_GPS_KEYS.has(key)) {
      throw new Error(`Unexpected GPS field "${key}" leaked in HTTP response`);
    }
    assertNoGpsFields(value);
  }
}

export function createE2eClient(sendRequest: E2eFetchFn): E2eClient {
  return {
    request: async (path, options) => {
      const url = new URL(path, E2E_BASE_URL).toString();
      const headers: Record<string, string> = {};
      if (options?.token !== undefined) {
        headers['Authorization'] = `Bearer ${options.token}`;
      }
      let body: string | Uint8Array<ArrayBuffer> | undefined;
      if (options?.json !== undefined) {
        headers['content-type'] = 'application/json';
        body = JSON.stringify(options.json);
      } else if (options?.body !== undefined) {
        headers['content-type'] = options.contentType ?? MEDIA_CONTENT_TYPE_JPEG;
        body = options.body;
      }
      const init: RequestInit = {
        method: options?.method ?? 'GET',
        headers,
        ...(body !== undefined ? { body } : {}),
      };
      return sendRequest(new Request(url, init));
    },
  };
}
