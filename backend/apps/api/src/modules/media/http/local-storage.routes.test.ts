import { HTTP_STATUS, ProblemDetailsSchema } from '@stanmieszkania/http-contracts';
import { FixedClock, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../../../app';
import { createD1TestHarness, type D1TestHarness } from '../../../testing/d1-test-harness';
import { ApartmentDtoSchema } from '../../apartments';
import { buildMediaR2Key } from '../domain/media.entity';
import { InitMediaUploadResponseSchema } from './media.schema';

async function sha256Hex(bytes: Uint8Array<ArrayBuffer>): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

describe('Local storage signed PUT enforcement', () => {
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

  it('rejects wrong Content-Type, byte mismatch, tampered bytes query, and invalid expires on signed PUT', async () => {
    const app = createApp({ overrides: { clock: new FixedClock(), idGenerator: ids } });
    const env = {
      DB: getHarness().db,
      MEDIA_BUCKET: getHarness().r2,
      AUTH_MODE: 'local',
      STORAGE_MODE: 'local',
    };
    const aptId = '01933e2a-7b40-7000-8000-000000000060';
    const medId = '01933e2a-7b40-7000-8000-000000000061';
    const jpegBytes = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
    const validSha = await sha256Hex(jpegBytes);

    ApartmentDtoSchema.parse(
      await (
        await app.request(
          `/v1/apartments/${aptId}`,
          {
            method: 'PUT',
            headers: { Authorization: 'Bearer dev:own-ls:Jan', 'Content-Type': 'application/json' },
            body: JSON.stringify({ name: 'M1', street: 'S1', city: 'Warszawa' }),
          },
          env,
        )
      ).json(),
    );

    const init = InitMediaUploadResponseSchema.parse(
      await (
        await app.request(
          `/v1/apartments/${aptId}/media/${medId}/init`,
          {
            method: 'POST',
            headers: { Authorization: 'Bearer dev:own-ls', 'Content-Type': 'application/json' },
            body: JSON.stringify({
              kind: 'photo',
              source: 'camera',
              sha256: validSha,
              capturedAt: '2026-11-18T12:00:00.000Z',
              capturedTz: 'Europe/Warsaw',
              width: 1200,
              height: 900,
              bytes: jpegBytes.byteLength,
            }),
          },
          env,
        )
      ).json(),
    );
    const putUrl = init.upload?.url ?? '';

    const htmlRes = await app.request(
      putUrl,
      { method: 'PUT', headers: { 'Content-Type': 'text/html' }, body: jpegBytes },
      env,
    );
    expect(htmlRes.status).toBe(HTTP_STATUS.FORBIDDEN);
    expect(ProblemDetailsSchema.parse(await htmlRes.json()).code).toBe('FORBIDDEN');

    const shortBodyRes = await app.request(
      putUrl,
      {
        method: 'PUT',
        headers: { 'Content-Type': 'image/jpeg' },
        body: new Uint8Array([0xff, 0xd8]),
      },
      env,
    );
    expect(shortBodyRes.status).toBe(HTTP_STATUS.FORBIDDEN);

    const badLenHeader = await app.request(
      putUrl,
      {
        method: 'PUT',
        headers: { 'Content-Type': 'image/jpeg', 'Content-Length': '99' },
        body: jpegBytes,
      },
      env,
    );
    expect(badLenHeader.status).toBe(HTTP_STATUS.FORBIDDEN);

    const tamperedBytesUrl = putUrl.replace(`bytes=${String(jpegBytes.byteLength)}`, 'bytes=999');
    const tamperedBytesRes = await app.request(
      tamperedBytesUrl,
      { method: 'PUT', headers: { 'Content-Type': 'image/jpeg' }, body: jpegBytes },
      env,
    );
    expect(tamperedBytesRes.status).toBe(HTTP_STATUS.FORBIDDEN);

    const invalidExpiresUrl = putUrl.replace(/expires=\d+/, 'expires=123abc');
    const invalidExpiresRes = await app.request(
      invalidExpiresUrl,
      { method: 'PUT', headers: { 'Content-Type': 'image/jpeg' }, body: jpegBytes },
      env,
    );
    expect(invalidExpiresRes.status).toBe(HTTP_STATUS.FORBIDDEN);

    expect(await getHarness().r2.get(buildMediaR2Key(aptId, medId))).toBeNull();
  });
});
