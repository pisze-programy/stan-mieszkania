import {
  createDomainError,
  err,
  ok,
  type Clock,
  type DomainError,
  type Result,
} from '@stanmieszkania/shared';
import type { ObjectStoragePort } from '../domain/object-storage.port';
import {
  buildCanonicalSigningPayload,
  DEFAULT_LOCAL_SIGNING_SECRET,
  signPayload,
  toHex,
  verifyLocalStorageSignature,
} from './local-storage-signing';

export { verifyLocalStorageSignature };
export const LOCAL_STORAGE_ROUTE_PATH = '/v1/local-storage/objects';

export interface LocalR2HeadLike {
  readonly size: number;
  readonly etag?: string;
}

export interface LocalR2ObjectBodyLike extends LocalR2HeadLike {
  arrayBuffer(): Promise<ArrayBuffer>;
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

function storageUnavailableError(message: string): DomainError {
  return createDomainError('STORAGE_UNAVAILABLE', message);
}

async function issueSignedUrl(params: {
  readonly secret: string;
  readonly nowMs: number;
  readonly expiresInMs: number;
  readonly method: 'PUT' | 'GET';
  readonly r2Key: string;
  readonly bytes?: number;
  readonly contentType?: string;
}): Promise<Result<{ readonly url: string; readonly expiresAt: string }, DomainError>> {
  const expiresMs = params.nowMs + params.expiresInMs;
  const sig = await signPayload(
    params.secret,
    buildCanonicalSigningPayload(
      params.method,
      params.r2Key,
      expiresMs,
      params.bytes,
      params.contentType,
    ),
  );
  const query = new URLSearchParams({
    key: params.r2Key,
    method: params.method,
    expires: String(expiresMs),
    ...(params.bytes !== undefined ? { bytes: String(params.bytes) } : {}),
    ...(params.contentType !== undefined ? { contentType: params.contentType } : {}),
    sig,
  });
  return ok({
    url: `${LOCAL_STORAGE_ROUTE_PATH}?${query.toString()}`,
    expiresAt: new Date(expiresMs).toISOString(),
  });
}

export function createLocalR2ObjectStorage(deps: LocalR2ObjectStorageDeps): ObjectStoragePort {
  const secret = deps.signingSecret ?? DEFAULT_LOCAL_SIGNING_SECRET;
  const missingBucket = (): Result<never, DomainError> =>
    err(storageUnavailableError('MEDIA_BUCKET binding is not configured'));

  return {
    createPresignedPutUrl: ({ r2Key, contentType, bytes, expiresInMs }) =>
      issueSignedUrl({
        secret,
        nowMs: deps.clock.nowMs(),
        expiresInMs,
        method: 'PUT',
        r2Key,
        bytes,
        contentType,
      }),
    createPresignedGetUrl: ({ r2Key, expiresInMs }) =>
      issueSignedUrl({ secret, nowMs: deps.clock.nowMs(), expiresInMs, method: 'GET', r2Key }),
    headObject: async (r2Key) => {
      if (deps.bucket === undefined) return missingBucket();
      const head = await deps.bucket.head(r2Key);
      return ok(head === null ? null : { bytes: head.size, sha256: null, etag: head.etag ?? null });
    },
    readObjectSha256: async (r2Key) => {
      if (deps.bucket === undefined) return missingBucket();
      const obj = await deps.bucket.get(r2Key);
      if (obj === null) return ok(null);
      const digest = await crypto.subtle.digest('SHA-256', await obj.arrayBuffer());
      return ok(toHex(new Uint8Array(digest)));
    },
    deleteObject: async (r2Key) => {
      if (deps.bucket === undefined) return missingBucket();
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
