import { HTTP_STATUS } from '@stanmieszkania/http-contracts';
import { createDomainError, type Clock } from '@stanmieszkania/shared';
import { Hono, type Context } from 'hono';
import type { StorageMode } from '../../../config/app-config';
import {
  notFoundErrorResponse,
  respondDomainError,
} from '../../../http/domain-error-to-http.mapper';
import { COMMON_ERROR_CODES, DIGITS_ONLY_REGEX } from '../../../http/http.constants';
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
    readonly bytes?: number;
    readonly contentType?: string;
    readonly signatureHex: string;
    readonly nowMs: number;
  }) => Promise<boolean>;
}

const SIGNED_QUERY_RADIX = 10;

type AuthorizedPutResult =
  | {
      readonly ok: true;
      readonly key: string;
      readonly signedBytes: number;
      readonly contentType: string;
    }
  | { readonly ok: false; readonly response: Response };

type AuthorizedGetResult =
  { readonly ok: true; readonly key: string } | { readonly ok: false; readonly response: Response };

function forbiddenResponse<E extends { Variables: HttpContextVariables }>(
  c: Context<E>,
  message: string,
): Response {
  return respondDomainError(
    c,
    createDomainError(COMMON_ERROR_CODES.FORBIDDEN, message),
    c.get('requestId'),
    [HTTP_STATUS.FORBIDDEN],
  );
}

function parsePositiveSafeInt(raw: string): number | null {
  if (!DIGITS_ONLY_REGEX.test(raw)) return null;
  const parsed = Number.parseInt(raw, SIGNED_QUERY_RADIX);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : null;
}

async function authorizePut<E extends { Variables: HttpContextVariables }>(
  c: Context<E>,
  deps: LocalStorageHandlers,
): Promise<AuthorizedPutResult> {
  if (deps.storageMode !== 'local') {
    return { ok: false, response: notFoundErrorResponse(c, c.get('requestId')) };
  }
  const key = c.req.query('key') ?? '';
  const method = (c.req.query('method') ?? '').toUpperCase();
  const expiresMs = parsePositiveSafeInt(c.req.query('expires') ?? '');
  const signedBytes = parsePositiveSafeInt(c.req.query('bytes') ?? '');
  const contentType = c.req.query('contentType') ?? '';
  const sig = c.req.query('sig') ?? '';

  const valid =
    key.length > 0 &&
    method === 'PUT' &&
    expiresMs !== null &&
    signedBytes !== null &&
    contentType === MEDIA_CONTENT_TYPE_JPEG &&
    (await deps.verifySignature({
      method: 'PUT',
      r2Key: key,
      expiresMs,
      bytes: signedBytes,
      contentType,
      signatureHex: sig,
      nowMs: deps.clock.nowMs(),
    }));

  if (!valid) {
    return {
      ok: false,
      response: forbiddenResponse(c, 'Invalid or expired local storage signature'),
    };
  }

  const rawHeaderCt =
    (c.req.header('Content-Type') ?? '').split(';')[0]?.trim().toLowerCase() ?? '';
  if (rawHeaderCt !== MEDIA_CONTENT_TYPE_JPEG) {
    return { ok: false, response: forbiddenResponse(c, 'Content-Type must be image/jpeg') };
  }

  const rawLen = c.req.header('Content-Length');
  if (rawLen !== undefined) {
    const parsedLen = parsePositiveSafeInt(rawLen.trim());
    if (parsedLen !== signedBytes) {
      return {
        ok: false,
        response: forbiddenResponse(c, 'Content-Length does not match signed bytes'),
      };
    }
  }

  return { ok: true, key, signedBytes, contentType };
}

async function authorizeGet<E extends { Variables: HttpContextVariables }>(
  c: Context<E>,
  deps: LocalStorageHandlers,
): Promise<AuthorizedGetResult> {
  if (deps.storageMode !== 'local') {
    return { ok: false, response: notFoundErrorResponse(c, c.get('requestId')) };
  }
  const key = c.req.query('key') ?? '';
  const method = (c.req.query('method') ?? '').toUpperCase();
  const expiresMs = parsePositiveSafeInt(c.req.query('expires') ?? '');
  const sig = c.req.query('sig') ?? '';

  const valid =
    key.length > 0 &&
    method === 'GET' &&
    expiresMs !== null &&
    (await deps.verifySignature({
      method: 'GET',
      r2Key: key,
      expiresMs,
      signatureHex: sig,
      nowMs: deps.clock.nowMs(),
    }));

  if (!valid) {
    return {
      ok: false,
      response: forbiddenResponse(c, 'Invalid or expired local storage signature'),
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
    const auth = await authorizePut(c, deps);
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
    if (body.byteLength !== auth.signedBytes) {
      return forbiddenResponse(c, 'Request body byte length does not match signed bytes');
    }
    await deps.bucket.put(auth.key, body, { httpMetadata: { contentType: auth.contentType } });
    return c.json({ ok: true, bytes: body.byteLength }, HTTP_STATUS.OK);
  });

  routes.get('/local-storage/objects', async (c) => {
    const deps = resolveHandlers(c);
    const auth = await authorizeGet(c, deps);
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
