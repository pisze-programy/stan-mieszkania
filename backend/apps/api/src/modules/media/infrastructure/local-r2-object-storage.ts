import {
  createDomainError,
  err,
  ok,
  type Clock,
  type DomainError,
  type Result,
} from '@stanmieszkania/shared';
import type { ObjectStoragePort } from '../domain/object-storage.port';

export const LOCAL_STORAGE_ROUTE_PATH = '/v1/local-storage/objects';
const DEFAULT_LOCAL_SIGNING_SECRET = 'stanmieszkania-local-r2-dev-signing-secret';
const HEX_RADIX = 16;
const HEX_PAD_WIDTH = 2;
const BYTE_HIGH_NIBBLE_MASK = 0xff;

export interface LocalR2ObjectBodyLike {
  readonly size: number;
  readonly etag?: string;
  arrayBuffer(): Promise<ArrayBuffer>;
}

export interface LocalR2HeadLike {
  readonly size: number;
  readonly etag?: string;
}

export interface LocalR2BucketLike {
  put(
    key: string,
    value: ArrayBuffer | ArrayBufferView | string | null,
    options?: { readonly httpMetadata?: { readonly contentType?: string } },
  ): Promise<unknown>;
  get(key: string): Promise<LocalR2ObjectBodyLike | null>;
  head(key: string): Promise<LocalR2HeadLike | null>;
  delete(keys: string | string[]): Promise<void>;
}

export interface LocalR2ObjectStorageDeps {
  readonly bucket: LocalR2BucketLike | undefined;
  readonly clock: Clock;
  readonly signingSecret?: string;
}

const textEncoder = new TextEncoder();

function toHex(bytes: Uint8Array): string {
  let out = '';
  for (const byte of bytes) {
    out += (byte & BYTE_HIGH_NIBBLE_MASK).toString(HEX_RADIX).padStart(HEX_PAD_WIDTH, '0');
  }
  return out;
}

function fromHex(hex: string): Uint8Array<ArrayBuffer> | null {
  if (hex.length === 0 || hex.length % HEX_PAD_WIDTH !== 0 || !/^[0-9a-f]+$/i.test(hex)) {
    return null;
  }
  const bytes = new Uint8Array(new ArrayBuffer(hex.length / HEX_PAD_WIDTH));
  for (let index = 0; index < bytes.length; index += 1) {
    bytes[index] = Number.parseInt(
      hex.slice(index * HEX_PAD_WIDTH, (index + 1) * HEX_PAD_WIDTH),
      HEX_RADIX,
    );
  }
  return bytes;
}

async function importHmacKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    'raw',
    textEncoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign', 'verify'],
  );
}

async function signPayload(secret: string, payload: string): Promise<string> {
  const key = await importHmacKey(secret);
  const sig = await crypto.subtle.sign('HMAC', key, textEncoder.encode(payload));
  return toHex(new Uint8Array(sig));
}

export async function verifyLocalStorageSignature(params: {
  readonly method: string;
  readonly r2Key: string;
  readonly expiresMs: number;
  readonly signatureHex: string;
  readonly nowMs: number;
  readonly signingSecret?: string;
}): Promise<boolean> {
  if (!Number.isFinite(params.expiresMs) || params.nowMs > params.expiresMs) {
    return false;
  }
  const sigBytes = fromHex(params.signatureHex);
  if (sigBytes === null) {
    return false;
  }
  const secret = params.signingSecret ?? DEFAULT_LOCAL_SIGNING_SECRET;
  const key = await importHmacKey(secret);
  const payload = `${params.method.toUpperCase()}\n${params.r2Key}\n${String(params.expiresMs)}`;
  return crypto.subtle.verify('HMAC', key, sigBytes, textEncoder.encode(payload));
}

function buildSignedUrl(
  method: 'PUT' | 'GET',
  r2Key: string,
  expiresMs: number,
  sigHex: string,
): string {
  const params = new URLSearchParams({
    key: r2Key,
    method,
    expires: String(expiresMs),
    sig: sigHex,
  });
  return `${LOCAL_STORAGE_ROUTE_PATH}?${params.toString()}`;
}

function storageUnavailableError(message: string): DomainError {
  return createDomainError('STORAGE_UNAVAILABLE', message);
}

export function createLocalR2ObjectStorage(deps: LocalR2ObjectStorageDeps): ObjectStoragePort {
  const secret = deps.signingSecret ?? DEFAULT_LOCAL_SIGNING_SECRET;

  return {
    createPresignedPutUrl: async ({ r2Key, expiresInMs }) => {
      const expiresMs = deps.clock.nowMs() + expiresInMs;
      const sig = await signPayload(secret, `PUT\n${r2Key}\n${String(expiresMs)}`);
      return ok({
        url: buildSignedUrl('PUT', r2Key, expiresMs, sig),
        expiresAt: new Date(expiresMs).toISOString(),
      });
    },
    createPresignedGetUrl: async ({ r2Key, expiresInMs }) => {
      const expiresMs = deps.clock.nowMs() + expiresInMs;
      const sig = await signPayload(secret, `GET\n${r2Key}\n${String(expiresMs)}`);
      return ok({
        url: buildSignedUrl('GET', r2Key, expiresMs, sig),
        expiresAt: new Date(expiresMs).toISOString(),
      });
    },
    headObject: async (r2Key) => {
      if (deps.bucket === undefined) {
        return err(storageUnavailableError('MEDIA_BUCKET binding is not configured'));
      }
      const head = await deps.bucket.head(r2Key);
      if (head === null) {
        return ok(null);
      }
      return ok({ bytes: head.size, sha256: null, etag: head.etag ?? null });
    },
    readObjectSha256: async (r2Key) => {
      if (deps.bucket === undefined) {
        return err(storageUnavailableError('MEDIA_BUCKET binding is not configured'));
      }
      const obj = await deps.bucket.get(r2Key);
      if (obj === null) {
        return ok(null);
      }
      const buffer = await obj.arrayBuffer();
      const digest = await crypto.subtle.digest('SHA-256', buffer);
      return ok(toHex(new Uint8Array(digest)));
    },
    deleteObject: async (r2Key) => {
      if (deps.bucket === undefined) {
        return err(storageUnavailableError('MEDIA_BUCKET binding is not configured'));
      }
      await deps.bucket.delete(r2Key);
      return ok(undefined);
    },
  };
}

export function createFailClosedObjectStorage(): ObjectStoragePort {
  const unavailable = (): Promise<Result<never, DomainError>> =>
    Promise.resolve(
      err(
        storageUnavailableError('Live R2 presigned URL generation requires storageMode=r2 adapter'),
      ),
    );
  return {
    createPresignedPutUrl: unavailable,
    createPresignedGetUrl: unavailable,
    headObject: unavailable,
    readObjectSha256: unavailable,
    deleteObject: unavailable,
  };
}
