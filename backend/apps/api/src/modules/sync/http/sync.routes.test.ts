import { HTTP_STATUS } from '@stanmieszkania/http-contracts';
import { exhaustCursorPages } from '@stanmieszkania/shared';
import { FixedClock, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../../../app';
import { createD1TestHarness, type D1TestHarness } from '../../../testing/d1-test-harness';
import { ApartmentDtoSchema } from '../../apartments';
import { InitMediaUploadResponseSchema } from '../../media';
import {
  MyApartmentsSyncResponseSchema,
  SyncChangesResponseSchema,
  type SyncChangesResponseDto,
} from './sync.schema';

async function sha256Hex(bytes: Uint8Array<ArrayBuffer>): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

describe('Sync HTTP routes (/v1/apartments/{id}/changes & /v1/me/apartments)', () => {
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

  it('exhausts multi-page hydrated changes, enforces Q10/Q4/S2-3 redaction, and returns accurate /v1/me/apartments headSeq', async () => {
    const clock = new FixedClock();
    const app = createApp({ overrides: { clock, idGenerator: ids } });
    const env = {
      DB: getHarness().db,
      MEDIA_BUCKET: getHarness().r2,
      AUTH_MODE: 'local',
      STORAGE_MODE: 'local',
    };
    const aptId = '01933e2a-7b40-7000-8000-000000000040';
    const medId = '01933e2a-7b40-7000-8000-000000000041';
    const entId = '01933e2a-7b40-7000-8000-000000000042';
    const mrkId = '01933e2a-7b40-7000-8000-000000000043';
    const jpegBytes = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
    const validSha = await sha256Hex(jpegBytes);

    const apt = ApartmentDtoSchema.parse(
      await (
        await app.request(
          `/v1/apartments/${aptId}`,
          {
            method: 'PUT',
            headers: { Authorization: 'Bearer dev:own-s:Jan', 'Content-Type': 'application/json' },
            body: JSON.stringify({ name: 'M1', street: 'S1', city: 'Warszawa' }),
          },
          env,
        )
      ).json(),
    );
    await app.request(
      `/v1/apartments/${aptId}`,
      {
        method: 'PATCH',
        headers: { Authorization: 'Bearer dev:own-s', 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: 'M1 New' }),
      },
      env,
    );
    await app.request(
      '/v1/apartments/join',
      {
        method: 'POST',
        headers: { Authorization: 'Bearer dev:cnt-s:Anna', 'Content-Type': 'application/json' },
        body: JSON.stringify({ inviteCode: apt.inviteCode }),
      },
      env,
    );

    const init = InitMediaUploadResponseSchema.parse(
      await (
        await app.request(
          `/v1/apartments/${aptId}/media/${medId}/init`,
          {
            method: 'POST',
            headers: { Authorization: 'Bearer dev:cnt-s', 'Content-Type': 'application/json' },
            body: JSON.stringify({
              kind: 'photo',
              source: 'camera',
              sha256: validSha,
              capturedAt: '2026-11-18T12:02:00.000Z',
              capturedTz: 'Europe/Warsaw',
              width: 1200,
              height: 900,
              bytes: jpegBytes.byteLength,
              lat: 52.23,
              lng: 21.01,
              accuracyM: 5,
              locationSource: 'device',
            }),
          },
          env,
        )
      ).json(),
    );
    await app.request(init.upload?.url ?? '', { method: 'PUT', body: jpegBytes }, env);
    await app.request(
      `/v1/apartments/${aptId}/media/${medId}/confirm`,
      { method: 'POST', headers: { Authorization: 'Bearer dev:cnt-s' } },
      env,
    );

    await app.request(
      `/v1/apartments/${aptId}/media/${medId}/entries/${entId}`,
      {
        method: 'PUT',
        headers: { Authorization: 'Bearer dev:cnt-s', 'Content-Type': 'application/json' },
        body: JSON.stringify({
          text: 'Rysa [1]',
          markers: [{ id: mrkId, localNumber: 1, x: 0.4, y: 0.6 }],
        }),
      },
      env,
    );
    await app.request(
      `/v1/apartments/${aptId}/media/${medId}/entries/${entId}`,
      { method: 'DELETE', headers: { Authorization: 'Bearer dev:cnt-s' } },
      env,
    );

    const allChanges = await exhaustCursorPages<SyncChangesResponseDto['changes'][number], number>(
      async (cursor) => {
        const res = await app.request(
          `/v1/apartments/${aptId}/changes?after=${String(cursor ?? 0)}&limit=2`,
          { headers: { Authorization: 'Bearer dev:cnt-s' } },
          env,
        );
        expect(res.status).toBe(HTTP_STATUS.OK);
        const page = SyncChangesResponseSchema.parse(await res.json());
        return { items: page.changes, nextCursor: page.nextSeq, hasMore: page.hasMore };
      },
      0,
    );

    expect(allChanges.map((c) => c.op)).toEqual([
      'created',
      'updated',
      'joined',
      'pending',
      'confirmed',
      'created',
      'retracted',
    ]);

    const aptPayload = allChanges[0]?.payload;
    if (aptPayload?.kind === 'apartment') {
      expect(aptPayload.apartment.inviteCode).toBeNull();
      expect(aptPayload.apartment.shouldSuggestInviteCodeReset).toBe(false);
    }
    const mediaPayload = allChanges[4]?.payload;
    expect(mediaPayload?.kind).toBe('media');
    const rawMediaJson = JSON.stringify(mediaPayload);
    for (const forbidden of ['"lat"', '"lng"', '"accuracyM"', '"locationSource"', '"r2Key"']) {
      expect(rawMediaJson).not.toContain(forbidden);
    }
    const entryPayload = allChanges[6]?.payload;
    expect(entryPayload?.kind).toBe('entry');
    if (entryPayload?.kind === 'entry') {
      expect(entryPayload.entry.text).toBe('');
      expect(entryPayload.entry.markers).toEqual([]);
      expect(entryPayload.entry.retractedAt).not.toBeNull();
    }

    const lastSeq = allChanges[allChanges.length - 1]?.seq ?? 0;
    const ownerMe = MyApartmentsSyncResponseSchema.parse(
      await (
        await app.request(
          '/v1/me/apartments',
          { headers: { Authorization: 'Bearer dev:own-s' } },
          env,
        )
      ).json(),
    );
    expect(ownerMe.items[0]).toMatchObject({
      role: 'owner',
      headSeq: lastSeq,
      confirmedMediaCount: 1,
      latestMediaCapturedAt: '2026-11-18T12:02:00.000Z',
    });
    expect(ownerMe.items[0]?.apartment.inviteCode).toBe(apt.inviteCode);
    expect(ownerMe.items[0]?.apartment.shouldSuggestInviteCodeReset).toBe(true);

    const contribMe = MyApartmentsSyncResponseSchema.parse(
      await (
        await app.request(
          '/v1/me/apartments',
          { headers: { Authorization: 'Bearer dev:cnt-s' } },
          env,
        )
      ).json(),
    );
    expect(contribMe.items[0]?.apartment.inviteCode).toBeNull();
    expect(contribMe.items[0]?.apartment.shouldSuggestInviteCodeReset).toBe(false);

    const strangerRes = await app.request(
      `/v1/apartments/${aptId}/changes?after=0`,
      { headers: { Authorization: 'Bearer dev:stranger-s' } },
      env,
    );
    expect(strangerRes.status).toBe(HTTP_STATUS.FORBIDDEN);
  });
});
