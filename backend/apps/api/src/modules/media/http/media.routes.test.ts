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

type App = ReturnType<typeof createApp>;

async function sha256Hex(bytes: Uint8Array<ArrayBuffer>): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

const apiReq = (
  app: App,
  path: string,
  token: string,
  env: Record<string, unknown>,
  method = 'GET',
  body?: unknown,
) =>
  app.request(
    path,
    {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
      },
      ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
    },
    env,
  );

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

  it('supports init -> local R2 PUT -> confirm -> download-url -> GET without leaking GPS, plus pending isolation, hash mismatch, soft-delete, and quota', async () => {
    const app = createApp({ overrides: { clock: new FixedClock(), idGenerator: ids } });
    const env = {
      DB: getHarness().db,
      MEDIA_BUCKET: getHarness().r2,
      AUTH_MODE: 'local',
      STORAGE_MODE: 'local',
      CLOUD_MEDIA_QUOTA_PER_APARTMENT: '1',
    };
    const req = (path: string, token: string, method = 'GET', body?: unknown) =>
      apiReq(app, path, token, env, method, body);
    const aptId = '01933e2a-7b40-7000-8000-000000000030';
    const med1 = '01933e2a-7b40-7000-8000-000000000031';
    const med2 = '01933e2a-7b40-7000-8000-000000000032';
    const jpegBytes = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
    const validSha = await sha256Hex(jpegBytes);

    const apt = ApartmentDtoSchema.parse(
      await (
        await req(`/v1/apartments/${aptId}`, 'dev:own-m:Jan', 'PUT', {
          name: 'M1',
          street: 'S1',
          city: 'Warszawa',
        })
      ).json(),
    );
    await req('/v1/apartments/join', 'dev:cnt-m:Anna', 'POST', { inviteCode: apt.inviteCode });

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
    const initRes = await req(
      `/v1/apartments/${aptId}/media/${med1}/init`,
      'dev:cnt-m',
      'POST',
      initPayload,
    );
    expect(initRes.status).toBe(HTTP_STATUS.OK);
    const initDto = InitMediaUploadResponseSchema.parse(await initRes.json());
    expect(initDto.upload).not.toBeNull();

    expect((await req(`/v1/apartments/${aptId}/media/${med1}`, 'dev:own-m')).status).toBe(
      HTTP_STATUS.NOT_FOUND,
    );
    const ownerPendingList = MediaTimelineResponseSchema.parse(
      await (await req(`/v1/apartments/${aptId}/media`, 'dev:own-m')).json(),
    );
    expect(ownerPendingList.items).toHaveLength(0);
    expect((await req(`/v1/apartments/${aptId}/media/${med1}`, 'dev:cnt-m', 'DELETE')).status).toBe(
      HTTP_STATUS.CONFLICT,
    );

    expect(
      (await req(`/v1/apartments/${aptId}/media/${med1}/init`, 'dev:cnt-m', 'POST', initPayload))
        .status,
    ).toBe(HTTP_STATUS.OK);

    const quotaRes = await req(
      `/v1/apartments/${aptId}/media/${med2}/init`,
      'dev:own-m',
      'POST',
      initPayload,
    );
    expect(quotaRes.status).toBe(HTTP_STATUS.UNPROCESSABLE_ENTITY);
    expect(ProblemDetailsSchema.parse(await quotaRes.json()).code).toBe('QUOTA_EXCEEDED');

    const badPut = await app.request(
      initDto.upload?.url ?? '',
      {
        method: 'PUT',
        headers: { 'Content-Type': 'image/jpeg' },
        body: new Uint8Array([1, 2, 3, 4, 5, 6]),
      },
      env,
    );
    expect(badPut.status).toBe(HTTP_STATUS.OK);
    const badConfirm = await req(
      `/v1/apartments/${aptId}/media/${med1}/confirm`,
      'dev:cnt-m',
      'POST',
    );
    expect(badConfirm.status).toBe(HTTP_STATUS.UNPROCESSABLE_ENTITY);
    expect(ProblemDetailsSchema.parse(await badConfirm.json()).code).toBe('MEDIA_HASH_MISMATCH');
    expect(await getHarness().r2.get(buildMediaR2Key(aptId, med1))).toBeNull();

    const goodPut = await app.request(
      initDto.upload?.url ?? '',
      { method: 'PUT', headers: { 'Content-Type': 'image/jpeg' }, body: jpegBytes },
      env,
    );
    expect(goodPut.status).toBe(HTTP_STATUS.OK);
    const confirmRes = await req(
      `/v1/apartments/${aptId}/media/${med1}/confirm`,
      'dev:cnt-m',
      'POST',
    );
    expect(confirmRes.status).toBe(HTTP_STATUS.OK);
    expect(MediaDtoSchema.parse(await confirmRes.json()).uploadStatus).toBe('uploaded');

    const dlUrl = PresignedUrlDtoSchema.parse(
      await (await req(`/v1/apartments/${aptId}/media/${med1}/download-url`, 'dev:own-m')).json(),
    ).url;
    const downloaded = await app.request(dlUrl, {}, env);
    expect(downloaded.status).toBe(HTTP_STATUS.OK);
    expect(new Uint8Array(await downloaded.arrayBuffer())).toEqual(jpegBytes);
    expect((await app.request(dlUrl, {}, { ...env, STORAGE_MODE: 'r2' })).status).toBe(
      HTTP_STATUS.NOT_FOUND,
    );
    expect((await app.request(`${dlUrl}00`, {}, env)).status).toBe(HTTP_STATUS.FORBIDDEN);

    const rawDetail = (await (
      await req(`/v1/apartments/${aptId}/media/${med1}`, 'dev:own-m')
    ).json()) as Record<string, unknown>; // reason: verifying GPS fields are absent from wire JSON
    expect(MediaWithAuthorDtoSchema.parse(rawDetail).author.displayName).toBe('Anna');
    for (const key of ['lat', 'lng', 'accuracyM', 'locationSource', 'location', 'r2Key']) {
      expect(rawDetail[key]).toBeUndefined();
    }

    expect((await req(`/v1/apartments/${aptId}/media/${med1}`, 'dev:own-m', 'DELETE')).status).toBe(
      HTTP_STATUS.FORBIDDEN,
    );
    expect((await req(`/v1/apartments/${aptId}/media/${med1}`, 'dev:cnt-m', 'DELETE')).status).toBe(
      HTTP_STATUS.OK,
    );

    const timeline = MediaTimelineResponseSchema.parse(
      await (await req(`/v1/apartments/${aptId}/media?limit=10`, 'dev:own-m')).json(),
    );
    expect(timeline.items).toHaveLength(1);
    expect(timeline.items[0]?.deletedAt).not.toBeNull();
    expect(
      ApartmentDtoSchema.parse(await (await req(`/v1/apartments/${aptId}`, 'dev:own-m')).json())
        .cloudMediaCount,
    ).toBe(1);
  });
});
