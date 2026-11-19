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

type App = ReturnType<typeof createApp>;

async function sha256Hex(bytes: Uint8Array<ArrayBuffer>): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

const jsonReq = (
  app: App,
  path: string,
  token: string,
  env: Record<string, unknown>,
  method: string,
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

const okJson = async (
  app: App,
  path: string,
  token: string,
  env: Record<string, unknown>,
  method: string,
  body?: unknown,
): Promise<unknown> => {
  const res = await jsonReq(app, path, token, env, method, body);
  expect(res.status).toBe(HTTP_STATUS.OK);
  return res.json();
};

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
    const app = createApp({ overrides: { clock: new FixedClock(), idGenerator: ids } });
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
      await okJson(app, `/v1/apartments/${aptId}`, 'dev:own-s:Jan', env, 'PUT', {
        name: 'M1',
        street: 'S1',
        city: 'Warszawa',
      }),
    );
    await okJson(app, `/v1/apartments/${aptId}`, 'dev:own-s', env, 'PATCH', { name: 'M1 New' });
    await okJson(app, '/v1/apartments/join', 'dev:cnt-s:Anna', env, 'POST', {
      inviteCode: apt.inviteCode,
    });

    const init = InitMediaUploadResponseSchema.parse(
      await okJson(app, `/v1/apartments/${aptId}/media/${medId}/init`, 'dev:cnt-s', env, 'POST', {
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
    );
    const pendingFeedForOwner = SyncChangesResponseSchema.parse(
      await okJson(
        app,
        `/v1/apartments/${aptId}/changes?after=0&limit=10`,
        'dev:own-s',
        env,
        'GET',
      ),
    );
    const pendingChange = pendingFeedForOwner.changes.find((c) => c.entityId === medId);
    expect(pendingChange?.payload).toBeNull();

    const putRes = await app.request(
      init.upload?.url ?? '',
      { method: 'PUT', headers: { 'Content-Type': 'image/jpeg' }, body: jpegBytes },
      env,
    );
    expect(putRes.status).toBe(HTTP_STATUS.OK);
    await okJson(app, `/v1/apartments/${aptId}/media/${medId}/confirm`, 'dev:cnt-s', env, 'POST');
    await okJson(
      app,
      `/v1/apartments/${aptId}/media/${medId}/entries/${entId}`,
      'dev:cnt-s',
      env,
      'PUT',
      {
        text: 'Rysa [1]',
        createdAt: '2026-11-18T12:03:00.000Z',
        markers: [{ id: mrkId, localNumber: 1, x: 0.4, y: 0.6 }],
      },
    );
    await okJson(
      app,
      `/v1/apartments/${aptId}/media/${medId}/entries/${entId}`,
      'dev:cnt-s',
      env,
      'DELETE',
    );

    const allChanges = await exhaustCursorPages<SyncChangesResponseDto['changes'][number]>(
      async (cursor) => {
        const path = `/v1/apartments/${aptId}/changes?after=${String(cursor ?? 0)}&limit=2`;
        const page = SyncChangesResponseSchema.parse(
          await okJson(app, path, 'dev:cnt-s', env, 'GET'),
        );
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
    const rawMediaJson = JSON.stringify(allChanges[4]?.payload);
    for (const forbidden of ['"lat"', '"lng"', '"accuracyM"', '"locationSource"', '"r2Key"']) {
      expect(rawMediaJson).not.toContain(forbidden);
    }
    const entryPayload = allChanges[6]?.payload;
    if (entryPayload?.kind === 'entry') {
      expect(entryPayload.entry.text).toBe('');
      expect(entryPayload.entry.markers).toEqual([]);
      expect(entryPayload.entry.retractedAt).not.toBeNull();
    }

    const lastSeq = allChanges[allChanges.length - 1]?.seq ?? 0;
    const ownerMe = MyApartmentsSyncResponseSchema.parse(
      await okJson(app, '/v1/me/apartments', 'dev:own-s', env, 'GET'),
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
      await okJson(app, '/v1/me/apartments', 'dev:cnt-s', env, 'GET'),
    );
    expect(contribMe.items[0]?.apartment.inviteCode).toBeNull();
    expect(contribMe.items[0]?.apartment.shouldSuggestInviteCodeReset).toBe(false);
    expect(
      (await jsonReq(app, `/v1/apartments/${aptId}/changes?after=0`, 'dev:stranger-s', env, 'GET'))
        .status,
    ).toBe(HTTP_STATUS.FORBIDDEN);
  });
});
