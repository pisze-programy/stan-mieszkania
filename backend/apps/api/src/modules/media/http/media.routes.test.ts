import { HTTP_STATUS, ProblemDetailsSchema } from '@stanmieszkania/http-contracts';
import { FixedClock, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../../../app';
import { createD1TestHarness, type D1TestHarness } from '../../../testing/d1-test-harness';
import { ApartmentDtoSchema } from '../../apartments';
import { buildMediaR2Key } from '../domain/media.entity';
import {
  InitMediaUploadResponseSchema,
  MediaDtoSchema,
  MediaTimelineResponseSchema,
  MediaWithAuthorDtoSchema,
  PresignedUrlDtoSchema,
} from './media.schema';

async function sha256Hex(bytes: Uint8Array<ArrayBuffer>): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

describe('Media HTTP routes & local R2 signed storage', () => {
  let harness: D1TestHarness | undefined;
  const ids = new SequentialUuidV7Generator();

  const getHarness = (): D1TestHarness => {
    if (harness === undefined) throw new Error('D1 test harness was not initialized');
    return harness;
  };

  beforeAll(async () => {
    harness = await createD1TestHarness();
  });

  afterAll(async () => {
    await harness?.dispose();
  });

  it('supports init -> local R2 PUT -> confirm -> download-url -> GET without leaking GPS, plus hash mismatch cleanup, soft-delete, and quota', async () => {
    const clock = new FixedClock();
    const app = createApp({ overrides: { clock, idGenerator: ids } });
    const env = {
      DB: getHarness().db,
      MEDIA_BUCKET: getHarness().r2,
      AUTH_MODE: 'local',
      STORAGE_MODE: 'local',
      CLOUD_MEDIA_QUOTA_PER_APARTMENT: '1',
    };
    const aptId = '01933e2a-7b40-7000-8000-000000000030';
    const med1 = '01933e2a-7b40-7000-8000-000000000031';
    const med2 = '01933e2a-7b40-7000-8000-000000000032';
    const jpegBytes = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
    const validSha = await sha256Hex(jpegBytes);

    const apt = ApartmentDtoSchema.parse(
      await (
        await app.request(
          `/v1/apartments/${aptId}`,
          {
            method: 'PUT',
            headers: { Authorization: 'Bearer dev:own-m:Jan', 'Content-Type': 'application/json' },
            body: JSON.stringify({ name: 'M1', street: 'S1', city: 'Warszawa' }),
          },
          env,
        )
      ).json(),
    );
    await app.request(
      '/v1/apartments/join',
      {
        method: 'POST',
        headers: { Authorization: 'Bearer dev:cnt-m:Anna', 'Content-Type': 'application/json' },
        body: JSON.stringify({ inviteCode: apt.inviteCode }),
      },
      env,
    );

    const initPayload = {
      kind: 'photo',
      source: 'camera',
      sha256: validSha,
      capturedAt: '2026-11-18T12:00:00.000Z',
      capturedTz: 'Europe/Warsaw',
      width: 1200,
      height: 900,
      bytes: jpegBytes.byteLength,
      lat: 52.2297,
      lng: 21.0122,
      accuracyM: 6,
      locationSource: 'device',
    };

    const initRes = await app.request(
      `/v1/apartments/${aptId}/media/${med1}/init`,
      {
        method: 'POST',
        headers: { Authorization: 'Bearer dev:cnt-m', 'Content-Type': 'application/json' },
        body: JSON.stringify(initPayload),
      },
      env,
    );
    expect(initRes.status).toBe(HTTP_STATUS.OK);
    const initDto = InitMediaUploadResponseSchema.parse(await initRes.json());
    expect(initDto.upload).not.toBeNull();

    const retryRes = await app.request(
      `/v1/apartments/${aptId}/media/${med1}/init`,
      {
        method: 'POST',
        headers: { Authorization: 'Bearer dev:cnt-m', 'Content-Type': 'application/json' },
        body: JSON.stringify(initPayload),
      },
      env,
    );
    expect(retryRes.status).toBe(HTTP_STATUS.OK);

    const quotaRes = await app.request(
      `/v1/apartments/${aptId}/media/${med2}/init`,
      {
        method: 'POST',
        headers: { Authorization: 'Bearer dev:own-m', 'Content-Type': 'application/json' },
        body: JSON.stringify(initPayload),
      },
      env,
    );
    expect(quotaRes.status).toBe(HTTP_STATUS.UNPROCESSABLE_ENTITY);
    expect(ProblemDetailsSchema.parse(await quotaRes.json()).code).toBe('QUOTA_EXCEEDED');

    const badPut = await app.request(
      initDto.upload?.url ?? '',
      { method: 'PUT', body: new Uint8Array([1, 2, 3, 4, 5, 6]) },
      env,
    );
    expect(badPut.status).toBe(HTTP_STATUS.OK);
    const badConfirm = await app.request(
      `/v1/apartments/${aptId}/media/${med1}/confirm`,
      { method: 'POST', headers: { Authorization: 'Bearer dev:cnt-m' } },
      env,
    );
    expect(badConfirm.status).toBe(HTTP_STATUS.UNPROCESSABLE_ENTITY);
    expect(ProblemDetailsSchema.parse(await badConfirm.json()).code).toBe('MEDIA_HASH_MISMATCH');
    expect(await getHarness().r2.get(buildMediaR2Key(aptId, med1))).toBeNull();

    await app.request(initDto.upload?.url ?? '', { method: 'PUT', body: jpegBytes }, env);
    const confirmRes = await app.request(
      `/v1/apartments/${aptId}/media/${med1}/confirm`,
      { method: 'POST', headers: { Authorization: 'Bearer dev:cnt-m' } },
      env,
    );
    expect(confirmRes.status).toBe(HTTP_STATUS.OK);
    expect(MediaDtoSchema.parse(await confirmRes.json()).uploadStatus).toBe('uploaded');

    const dlRes = await app.request(
      `/v1/apartments/${aptId}/media/${med1}/download-url`,
      { headers: { Authorization: 'Bearer dev:own-m' } },
      env,
    );
    const dlUrl = PresignedUrlDtoSchema.parse(await dlRes.json()).url;
    const downloaded = await app.request(dlUrl, {}, env);
    expect(downloaded.status).toBe(HTTP_STATUS.OK);
    expect(new Uint8Array(await downloaded.arrayBuffer())).toEqual(jpegBytes);

    const r2Blocked = await app.request(dlUrl, {}, { ...env, STORAGE_MODE: 'r2' });
    expect(r2Blocked.status).toBe(HTTP_STATUS.NOT_FOUND);
    const tamperedSig = await app.request(`${dlUrl}00`, {}, env);
    expect(tamperedSig.status).toBe(HTTP_STATUS.FORBIDDEN);

    const getRes = await app.request(
      `/v1/apartments/${aptId}/media/${med1}`,
      { headers: { Authorization: 'Bearer dev:own-m' } },
      env,
    );
    const rawDetail = (await getRes.json()) as Record<string, unknown>; // reason: verifying GPS fields are absent from wire JSON
    expect(MediaWithAuthorDtoSchema.parse(rawDetail).author.displayName).toBe('Anna');
    for (const key of ['lat', 'lng', 'accuracyM', 'locationSource', 'location', 'r2Key']) {
      expect(rawDetail[key]).toBeUndefined();
    }

    const ownerDel = await app.request(
      `/v1/apartments/${aptId}/media/${med1}`,
      { method: 'DELETE', headers: { Authorization: 'Bearer dev:own-m' } },
      env,
    );
    expect(ownerDel.status).toBe(HTTP_STATUS.FORBIDDEN);

    const contribDel = await app.request(
      `/v1/apartments/${aptId}/media/${med1}`,
      { method: 'DELETE', headers: { Authorization: 'Bearer dev:cnt-m' } },
      env,
    );
    expect(contribDel.status).toBe(HTTP_STATUS.OK);

    const timeline = MediaTimelineResponseSchema.parse(
      await (
        await app.request(
          `/v1/apartments/${aptId}/media?limit=10`,
          { headers: { Authorization: 'Bearer dev:own-m' } },
          env,
        )
      ).json(),
    );
    expect(timeline.items).toHaveLength(1);
    expect(timeline.items[0]?.deletedAt).not.toBeNull();

    const aptAfter = ApartmentDtoSchema.parse(
      await (
        await app.request(
          `/v1/apartments/${aptId}`,
          { headers: { Authorization: 'Bearer dev:own-m' } },
          env,
        )
      ).json(),
    );
    expect(aptAfter.cloudMediaCount).toBe(1);
  });
});
