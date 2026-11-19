import { isErr, isOk } from '@stanmieszkania/shared';
import { FixedClock } from '@stanmieszkania/testing';
import { describe, expect, it } from 'vitest';
import { createFailClosedObjectStorage, type LocalR2BucketLike } from './local-r2-object-storage';
import {
  createR2S3ObjectStorage,
  createR2S3ObjectStorageOrFailClosed,
} from './r2-s3-object-storage';

const NOW_ISO = '2026-11-19T10:00:00.000Z';

function createMemoryBucket(): LocalR2BucketLike {
  const objects = new Map<string, Uint8Array<ArrayBuffer>>();
  return {
    put: (key, value) => {
      if (value instanceof Uint8Array) {
        const copy = new Uint8Array(new ArrayBuffer(value.byteLength));
        copy.set(value);
        objects.set(key, copy);
      }
      return Promise.resolve();
    },
    head: (key) => {
      const found = objects.get(key);
      return Promise.resolve(
        found !== undefined ? { size: found.byteLength, etag: 'etag-1' } : null,
      );
    },
    get: (key) => {
      const found = objects.get(key);
      if (found === undefined) return Promise.resolve(null);
      return Promise.resolve({
        size: found.byteLength,
        etag: 'etag-1',
        arrayBuffer: () => Promise.resolve(found.buffer.slice(0)),
      });
    },
    delete: (keys) => {
      const list = Array.isArray(keys) ? keys : [keys];
      for (const k of list) objects.delete(k);
      return Promise.resolve();
    },
  };
}

describe('R2S3ObjectStorage (EU jurisdiction S3v4 presigner + native R2 binding)', () => {
  it('generates deterministic EU S3v4 presigned PUT and GET URLs with exact signed headers', async () => {
    const clock = new FixedClock(NOW_ISO);
    const bucket = createMemoryBucket();
    const storage = createR2S3ObjectStorage({
      accountId: 'acc1234567890',
      bucketName: 'stanmieszkania-media-production',
      accessKeyId: 'AKIA_TEST_KEY',
      secretAccessKey: 'SECRET_TEST_VALUE_0123456789',
      bucket,
      clock,
    });

    const putA = await storage.createPresignedPutUrl({
      r2Key: 'apartments/apt-1/media/med-1.jpg',
      contentType: 'image/jpeg',
      bytes: 2048,
      sha256: 'a'.repeat(64),
      expiresInMs: 900_000,
    });
    const putB = await storage.createPresignedPutUrl({
      r2Key: 'apartments/apt-1/media/med-1.jpg',
      contentType: 'image/jpeg',
      bytes: 2048,
      sha256: 'a'.repeat(64),
      expiresInMs: 900_000,
    });
    expect(isOk(putA)).toBe(true);
    expect(putA).toEqual(putB);

    if (isOk(putA)) {
      const parsed = new URL(putA.value.url);
      expect(parsed.hostname).toBe('acc1234567890.eu.r2.cloudflarestorage.com');
      expect(parsed.pathname).toBe(
        '/stanmieszkania-media-production/apartments/apt-1/media/med-1.jpg',
      );
      expect(parsed.searchParams.get('X-Amz-Algorithm')).toBe('AWS4-HMAC-SHA256');
      expect(parsed.searchParams.get('X-Amz-Credential')).toBe(
        'AKIA_TEST_KEY/20261119/auto/s3/aws4_request',
      );
      expect(parsed.searchParams.get('X-Amz-Date')).toBe('20261119T100000Z');
      expect(parsed.searchParams.get('X-Amz-Expires')).toBe('900');
      expect(parsed.searchParams.get('X-Amz-SignedHeaders')).toBe(
        'content-length;content-type;host',
      );
      expect(parsed.searchParams.get('X-Amz-Signature')).toMatch(/^[0-9a-f]{64}$/);
      expect(putA.value.expiresAt).toBe('2026-11-19T10:15:00.000Z');
    }

    const putDifferentBytes = await storage.createPresignedPutUrl({
      r2Key: 'apartments/apt-1/media/med-1.jpg',
      contentType: 'image/jpeg',
      bytes: 4096,
      sha256: 'a'.repeat(64),
      expiresInMs: 900_000,
    });
    expect(
      isOk(putA) && isOk(putDifferentBytes) && putA.value.url !== putDifferentBytes.value.url,
    ).toBe(true);

    const getRes = await storage.createPresignedGetUrl({
      r2Key: 'apartments/apt-1/media/med-1.jpg',
      expiresInMs: 3_600_000,
    });
    expect(isOk(getRes)).toBe(true);
    if (isOk(getRes)) {
      const parsed = new URL(getRes.value.url);
      expect(parsed.hostname).toBe('acc1234567890.eu.r2.cloudflarestorage.com');
      expect(parsed.searchParams.get('X-Amz-SignedHeaders')).toBe('host');
      expect(parsed.searchParams.get('X-Amz-Expires')).toBe('3600');
      expect(parsed.searchParams.get('X-Amz-Signature')).toMatch(/^[0-9a-f]{64}$/);
    }
  });

  it('uses native R2 binding for head/sha256/delete and fails closed when S3 credentials are absent', async () => {
    const clock = new FixedClock(NOW_ISO);
    const bucket = createMemoryBucket();
    const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xe0]);
    await bucket.put('apartments/a/media/m.jpg', bytes);

    const storage = createR2S3ObjectStorage({
      accountId: 'acc1',
      bucketName: 'bucket1',
      accessKeyId: 'key1',
      secretAccessKey: 'sec1',
      bucket,
      clock,
    });

    const head = await storage.headObject('apartments/a/media/m.jpg');
    expect(isOk(head) && head.value).toEqual({ bytes: 4, sha256: null, etag: 'etag-1' });

    const sha = await storage.readObjectSha256('apartments/a/media/m.jpg');
    expect(isOk(sha) && sha.value).toMatch(/^[0-9a-f]{64}$/);

    expect(isOk(await storage.deleteObject('apartments/a/media/m.jpg'))).toBe(true);
    expect(isOk(await storage.headObject('apartments/a/media/m.jpg'))).toBe(true);
    const afterDelete = await storage.headObject('apartments/a/media/m.jpg');
    expect(isOk(afterDelete) && afterDelete.value).toBeNull();

    const failClosed = createR2S3ObjectStorageOrFailClosed(
      { accountId: 'acc1', bucket, clock },
      createFailClosedObjectStorage(),
    );
    const rejected = await failClosed.createPresignedPutUrl({
      r2Key: 'a/b.jpg',
      contentType: 'image/jpeg',
      bytes: 100,
      sha256: 'a'.repeat(64),
      expiresInMs: 60_000,
    });
    expect(isErr(rejected) && rejected.error.code).toBe('STORAGE_UNAVAILABLE');
  });
});
