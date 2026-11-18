import { HTTP_STATUS } from '@stanmieszkania/http-contracts';
import { createDomainError, type Clock } from '@stanmieszkania/shared';
import { Hono, type Context } from 'hono';
import type { StorageMode } from '../../../config/app-config';
import {
  notFoundErrorResponse,
  respondDomainError,
} from '../../../http/domain-error-to-http.mapper';
import { COMMON_ERROR_CODES } from '../../../http/http.constants';
import type { HttpContextVariables } from '../../../http/http-env';
import { MEDIA_CONTENT_TYPE_JPEG } from '../domain/media.constants';
import { MEDIA_ERROR_CODES } from '../domain/media.errors';

export interface LocalStorageBucketPort {
  put(
    key: string,
    value: ArrayBuffer | ArrayBufferView | string | null,
    options?: { readonly httpMetadata?: { readonly contentType?: string } },
  ): Promise<unknown>;
  get(key: string): Promise<{ arrayBuffer(): Promise<ArrayBuffer> } | null>;
}

export interface LocalStorageHandlers {
  readonly storageMode: StorageMode;
  readonly bucket: LocalStorageBucketPort | undefined;
  readonly clock: Clock;
  readonly verifySignature: (params: {
    readonly method: string;
    readonly r2Key: string;
    readonly expiresMs: number;
    readonly signatureHex: string;
    readonly nowMs: number;
  }) => Promise<boolean>;
}

const SIGNED_QUERY_RADIX = 10;

async function authorizeLocalStorage(
  c: Context,
  deps: LocalStorageHandlers,
  expectedMethod: 'PUT' | 'GET',
): Promise<
  { readonly ok: true; readonly key: string } | { readonly ok: false; readonly response: Response }
> {
  const requestId = c.get('requestId') as string;
  if (deps.storageMode !== 'local') {
    return { ok: false, response: notFoundErrorResponse(c, requestId) };
  }
  const key = c.req.query('key') ?? '';
  const method = (c.req.query('method') ?? '').toUpperCase();
  const expiresRaw = c.req.query('expires') ?? '';
  const sig = c.req.query('sig') ?? '';
  const expiresMs = Number.parseInt(expiresRaw, SIGNED_QUERY_RADIX);

  const valid =
    key.length > 0 &&
    method === expectedMethod &&
    Number.isFinite(expiresMs) &&
    (await deps.verifySignature({
      method: expectedMethod,
      r2Key: key,
      expiresMs,
      signatureHex: sig,
      nowMs: deps.clock.nowMs(),
    }));

  if (!valid) {
    return {
      ok: false,
      response: respondDomainError(
        c,
        createDomainError(
          COMMON_ERROR_CODES.FORBIDDEN,
          'Invalid or expired local storage signature',
        ),
        requestId,
        [HTTP_STATUS.FORBIDDEN],
      ),
    };
  }
  return { ok: true, key };
}

export function createLocalStorageRoutes<E extends { Variables: HttpContextVariables }>(
  resolveHandlers: (c: Context<E>) => LocalStorageHandlers,
) {
  const routes = new Hono<E>();

  routes.put('/local-storage/objects', async (c) => {
    const deps = resolveHandlers(c);
    const auth = await authorizeLocalStorage(c, deps, 'PUT');
    if (!auth.ok) return auth.response;

    if (deps.bucket === undefined) {
      return respondDomainError(
        c,
        createDomainError(COMMON_ERROR_CODES.INTERNAL_ERROR, 'MEDIA_BUCKET is not configured'),
        c.get('requestId'),
        [],
      );
    }
    const body = await c.req.arrayBuffer();
    const contentType = c.req.header('Content-Type') ?? MEDIA_CONTENT_TYPE_JPEG;
    await deps.bucket.put(auth.key, body, { httpMetadata: { contentType } });
    return c.json({ ok: true, bytes: body.byteLength }, HTTP_STATUS.OK);
  });

  routes.get('/local-storage/objects', async (c) => {
    const deps = resolveHandlers(c);
    const auth = await authorizeLocalStorage(c, deps, 'GET');
    if (!auth.ok) return auth.response;

    if (deps.bucket === undefined) {
      return respondDomainError(
        c,
        createDomainError(COMMON_ERROR_CODES.INTERNAL_ERROR, 'MEDIA_BUCKET is not configured'),
        c.get('requestId'),
        [],
      );
    }
    const obj = await deps.bucket.get(auth.key);
    if (obj === null) {
      return respondDomainError(
        c,
        createDomainError(MEDIA_ERROR_CODES.MEDIA_NOT_FOUND, 'Local media object was not found'),
        c.get('requestId'),
        [HTTP_STATUS.NOT_FOUND],
      );
    }
    const bytes = await obj.arrayBuffer();
    return new Response(bytes, {
      status: HTTP_STATUS.OK,
      headers: {
        'Content-Type': MEDIA_CONTENT_TYPE_JPEG,
        'Cache-Control': 'private, no-store',
      },
    });
  });

  return routes;
}
