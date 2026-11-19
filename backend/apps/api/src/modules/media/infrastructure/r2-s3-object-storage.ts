import { createDomainError, err, ok, type Clock, type DomainError } from '@stanmieszkania/shared';
import type { ObjectStoragePort } from '../domain/object-storage.port';
import type { LocalR2BucketLike } from './local-r2-object-storage';
import { presignR2Url, toHex } from './r2-sigv4-presigner';

export interface R2S3ObjectStorageDeps {
  readonly accountId: string;
  readonly bucketName: string;
  readonly accessKeyId: string;
  readonly secretAccessKey: string;
  readonly bucket: LocalR2BucketLike | undefined;
  readonly clock: Clock;
}

function storageUnavailableError(message: string): DomainError {
  return createDomainError('STORAGE_UNAVAILABLE', message);
}

// Decision 6.5 & A14: EU R2 S3v4 presigned PUT/GET URLs + native Worker R2 binding inspection/deletion.
export function createR2S3ObjectStorage(deps: R2S3ObjectStorageDeps): ObjectStoragePort {
  return {
    createPresignedPutUrl: async ({ r2Key, contentType, bytes, expiresInMs }) => {
      try {
        const signed = await presignR2Url({
          method: 'PUT',
          accountId: deps.accountId,
          bucketName: deps.bucketName,
          accessKeyId: deps.accessKeyId,
          secretAccessKey: deps.secretAccessKey,
          r2Key,
          nowMs: deps.clock.nowMs(),
          expiresInMs,
          contentType,
          contentLength: bytes,
        });
        return ok(signed);
      } catch {
        return err(storageUnavailableError('Failed to sign R2 PUT URL'));
      }
    },
    createPresignedGetUrl: async ({ r2Key, expiresInMs }) => {
      try {
        const signed = await presignR2Url({
          method: 'GET',
          accountId: deps.accountId,
          bucketName: deps.bucketName,
          accessKeyId: deps.accessKeyId,
          secretAccessKey: deps.secretAccessKey,
          r2Key,
          nowMs: deps.clock.nowMs(),
          expiresInMs,
        });
        return ok(signed);
      } catch {
        return err(storageUnavailableError('Failed to sign R2 GET URL'));
      }
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

export function createR2S3ObjectStorageOrFailClosed(
  deps: Partial<
    Pick<R2S3ObjectStorageDeps, 'accountId' | 'bucketName' | 'accessKeyId' | 'secretAccessKey'>
  > &
    Pick<R2S3ObjectStorageDeps, 'bucket' | 'clock'>,
  fallback: ObjectStoragePort,
): ObjectStoragePort {
  if (
    deps.accountId !== undefined &&
    deps.bucketName !== undefined &&
    deps.accessKeyId !== undefined &&
    deps.secretAccessKey !== undefined
  ) {
    return createR2S3ObjectStorage({
      accountId: deps.accountId,
      bucketName: deps.bucketName,
      accessKeyId: deps.accessKeyId,
      secretAccessKey: deps.secretAccessKey,
      bucket: deps.bucket,
      clock: deps.clock,
    });
  }
  return fallback;
}
