import { createStatement, queryFirst } from '@stanmieszkania/d1';
import { HTTP_STATUS } from '@stanmieszkania/http-contracts';
import { FixedClock, RecordingLogger, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { z } from 'zod';
import { createApp } from '../../app';
import { ApartmentDtoSchema, ApartmentHistoryResponseSchema } from '../../modules/apartments';
import { EntryListResponseSchema } from '../../modules/entries';
import { UserProfileSchema } from '../../modules/identity';
import {
  MediaTimelineResponseSchema,
  MediaWithAuthorDtoSchema,
  PresignedUrlDtoSchema,
} from '../../modules/media';
import { MyApartmentsSyncResponseSchema } from '../../modules/sync';
import { createD1TestHarness, type D1TestHarness } from '../d1-test-harness';
import { exhaustCursorPages, jsonOf, putApartment, putEntry, uploadPhoto } from './e2e-actions';
import { assertNoGpsFields, buildE2eEnv, createE2eClient, makeJpegBytes } from './e2e-client';

const gpsRowSchema = z.object({
  lat: z.number().nullable(),
  lng: z.number().nullable(),
  accuracy_m: z.number().nullable(),
  location_source: z.string().nullable(),
});

describe('E2E Handover & Dispute lifecycle (Miniflare D1 + R2 + ApartmentCoordinator + UserGuard)', () => {
  let harness: D1TestHarness | undefined;
  beforeAll(async () => {
    harness = await createD1TestHarness();
  });
  afterAll(async () => {
    await harness?.dispose();
  });

  it('executes full landlord-tenant handover, GPS stripping, invite reset, sync, marker numbering, retraction, and soft-delete', async () => {
    if (harness === undefined) throw new Error('D1 test harness was not initialized');
    const h = harness;
    const clock = new FixedClock(new Date(Date.now() + 7 * 86_400_000).toISOString());
    const ids = new SequentialUuidV7Generator();
    const app = createApp({
      overrides: { clock, idGenerator: ids, logger: new RecordingLogger() },
    });
    const env = buildE2eEnv(h);
    const c = createE2eClient((req) => app.fetch(req, env));
    const landlord = 'dev:e2e-landlord';
    const tenant = 'dev:e2e-tenant:Anna Nowak';

    const meFirst = UserProfileSchema.parse(await jsonOf(c, '/v1/me', landlord));
    expect(meFirst.displayName).toMatch(/^Użytkownik #[A-Z0-9]{4}$/);
    const meUpdated = UserProfileSchema.parse(
      await jsonOf(c, '/v1/me', landlord, 'PATCH', { displayName: 'Jan Kowalski' }),
    );
    expect(meUpdated.displayName).toBe('Jan Kowalski');

    const aptId = ids.nextId();
    const aptBody = { name: 'Mokotów 12', street: 'Puławska 12/4', city: 'Warszawa' };
    const apt1 = await putApartment(c, landlord, aptId, aptBody);
    expect((await putApartment(c, landlord, aptId, aptBody)).inviteCode).toBe(apt1.inviteCode);

    clock.advanceBy(1_000);
    await jsonOf(c, `/v1/apartments/${aptId}`, landlord, 'PATCH', { name: 'Mokotów 12A' });
    const history = ApartmentHistoryResponseSchema.parse(
      await jsonOf(c, `/v1/apartments/${aptId}/history`, landlord),
    );
    expect(history.items.map((x) => [x.field, x.oldValue, x.newValue])).toEqual([
      ['name', 'Mokotów 12', 'Mokotów 12A'],
    ]);

    const photo1Id = ids.nextId();
    const photo1Bytes = makeJpegBytes(0x01, 0x02);
    const photo1 = await uploadPhoto(c, {
      token: landlord,
      apartmentId: aptId,
      mediaId: photo1Id,
      bytes: photo1Bytes,
      capturedAt: clock.nowIso(),
      gps: { lat: 52.2297, lng: 21.0122, accuracyM: 5, locationSource: 'device' },
    });
    expect(photo1.mediaDto.sha256).toBe(photo1.sha256);
    expect(photo1.mediaDto.serverReceivedAt).not.toBeNull();

    const dbGps = await queryFirst(
      h.db,
      createStatement('SELECT lat, lng, accuracy_m, location_source FROM media WHERE id = ?', [
        photo1Id,
      ]),
      gpsRowSchema,
    );
    expect(dbGps.ok && dbGps.value).toEqual({
      lat: 52.2297,
      lng: 21.0122,
      accuracy_m: 5,
      location_source: 'device',
    });
    const rawDetail = await jsonOf(c, `/v1/apartments/${aptId}/media/${photo1Id}`, landlord);
    assertNoGpsFields(rawDetail);
    MediaWithAuthorDtoSchema.parse(rawDetail);

    const e1 = await putEntry(c, {
      token: landlord,
      apartmentId: aptId,
      mediaId: photo1Id,
      entryId: ids.nextId(),
      text: 'Wall scratch [1] and floor chip [2]',
      createdAt: clock.nowIso(),
      markers: [
        { id: ids.nextId(), localNumber: 1, x: 0.2, y: 0.3 },
        { id: ids.nextId(), localNumber: 2, x: 0.6, y: 0.7 },
      ],
    });
    expect(e1.markers.map((m) => m.number)).toEqual([1, 2]);

    const joined = ApartmentDtoSchema.parse(
      await jsonOf(c, '/v1/apartments/join', tenant, 'POST', { inviteCode: apt1.inviteCode }),
    );
    expect(joined.inviteCode).toBeNull();
    expect(
      ApartmentDtoSchema.parse(await jsonOf(c, `/v1/apartments/${aptId}`, landlord))
        .shouldSuggestInviteCodeReset,
    ).toBe(true);
    const rotated = ApartmentDtoSchema.parse(
      await jsonOf(c, `/v1/apartments/${aptId}/invite-code/reset`, landlord, 'POST'),
    );
    expect(rotated.inviteCode).not.toBe(apt1.inviteCode);
    expect(rotated.shouldSuggestInviteCodeReset).toBe(false);

    expect(
      MyApartmentsSyncResponseSchema.parse(await jsonOf(c, '/v1/me/apartments', tenant)).items[0]
        ?.headSeq,
    ).toBeGreaterThan(0);
    const initialFeed = await exhaustCursorPages(c, tenant, aptId, 0, 2);
    expect(initialFeed.pageCount).toBeGreaterThan(1);
    assertNoGpsFields(initialFeed.changes);

    const dlUrl = PresignedUrlDtoSchema.parse(
      await jsonOf(c, `/v1/apartments/${aptId}/media/${photo1Id}/download-url`, tenant),
    );
    const dlRes = await c.request(dlUrl.url);
    expect(dlRes.status).toBe(HTTP_STATUS.OK);
    expect(new Uint8Array(await dlRes.arrayBuffer())).toEqual(photo1Bytes);

    const dispute = await putEntry(c, {
      token: tenant,
      apartmentId: aptId,
      mediaId: photo1Id,
      entryId: ids.nextId(),
      text: 'Disputed dent [1]',
      createdAt: clock.nowIso(),
      markers: [{ id: ids.nextId(), localNumber: 1, x: 0.4, y: 0.5 }],
    });
    expect(dispute.markers.map((m) => m.number)).toEqual([3]);
    expect(dispute.text).toBe('Disputed dent [3]');

    await uploadPhoto(c, {
      token: tenant,
      apartmentId: aptId,
      mediaId: ids.nextId(),
      bytes: makeJpegBytes(0x09, 0x08),
      capturedAt: clock.nowIso(),
    });

    const mistakeId = ids.nextId();
    await putEntry(c, {
      token: tenant,
      apartmentId: aptId,
      mediaId: photo1Id,
      entryId: mistakeId,
      text: 'Wrong',
      createdAt: clock.nowIso(),
    });
    const retractRes = await c.request(
      `/v1/apartments/${aptId}/media/${photo1Id}/entries/${mistakeId}`,
      { method: 'DELETE', token: tenant },
    );
    expect(retractRes.status).toBe(HTTP_STATUS.OK);

    const entries = EntryListResponseSchema.parse(
      await jsonOf(c, `/v1/apartments/${aptId}/media/${photo1Id}/entries`, tenant),
    );
    const retracted = entries.items.find((e) => e.id === mistakeId);
    expect(retracted?.text).toBe('');
    expect(retracted?.markers).toEqual([]);
    expect(retracted?.retractedAt).not.toBeNull();

    const fourth = await putEntry(c, {
      token: tenant,
      apartmentId: aptId,
      mediaId: photo1Id,
      entryId: ids.nextId(),
      text: 'Follow-up [1]',
      createdAt: clock.nowIso(),
      markers: [{ id: ids.nextId(), localNumber: 1, x: 0.8, y: 0.8 }],
    });
    expect(fourth.markers.map((m) => m.number)).toEqual([4]);

    const delRes = await c.request(`/v1/apartments/${aptId}/media/${photo1Id}`, {
      method: 'DELETE',
      token: landlord,
    });
    expect(delRes.status).toBe(HTTP_STATUS.OK);
    const timeline = MediaTimelineResponseSchema.parse(
      await jsonOf(c, `/v1/apartments/${aptId}/media`, tenant),
    );
    assertNoGpsFields(timeline);
    const tombstone = timeline.items.find((item) => item.id === photo1Id);
    expect(tombstone?.deletedAt).not.toBeNull();
    expect(tombstone?.deletedBy).toBe(meFirst.id);

    const deltaFeed = await exhaustCursorPages(c, tenant, aptId, initialFeed.lastSeq, 5);
    expect(
      deltaFeed.changes.some((ch) => ch.entityId === photo1Id && ch.op === 'soft_deleted'),
    ).toBe(true);
    expect(
      ApartmentDtoSchema.parse(await jsonOf(c, `/v1/apartments/${aptId}`, landlord))
        .cloudMediaCount,
    ).toBe(2);
  });
});
