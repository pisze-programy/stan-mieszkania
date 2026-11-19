import { createStatement, queryFirst } from '@stanmieszkania/d1';
import { HTTP_STATUS, ProblemDetailsSchema } from '@stanmieszkania/http-contracts';
import { FixedClock, RecordingLogger, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { z } from 'zod';
import { createApp } from '../../app';
import { ApartmentDtoSchema } from '../../modules/apartments';
import { EntryListResponseSchema } from '../../modules/entries';
import {
  DELETED_USER_DISPLAY_NAME,
  IDENTITY_ERROR_CODES,
  UserProfileSchema,
} from '../../modules/identity';
import {
  MEDIA_ERROR_CODES,
  MediaTimelineResponseSchema,
  buildMediaR2Key,
} from '../../modules/media';
import {
  ApartmentMemberListResponseSchema,
  MEMBERSHIP_ERROR_CODES,
} from '../../modules/membership';
import { createD1TestHarness, type D1TestHarness } from '../d1-test-harness';
import { jsonOf, putApartment, putEntry, uploadPhoto } from './e2e-actions';
import { buildE2eEnv, createE2eClient, initMediaRaw, makeJpegBytes } from './e2e-client';

const idRowSchema = z.object({ id: z.string() });

describe('E2E Quota, Revocation, Rate-limit & Account Deletion (Miniflare D1 + R2 + DOs)', () => {
  let harness: D1TestHarness | undefined;
  beforeAll(async () => {
    harness = await createD1TestHarness();
  });
  afterAll(async () => {
    await harness?.dispose();
  });

  it('enforces quota with tombstones, invite rate limits, member revocation, and full GDPR account deletion', async () => {
    if (harness === undefined) throw new Error('D1 test harness was not initialized');
    const h = harness;
    const clock = new FixedClock(new Date(Date.now() + 7 * 86_400_000).toISOString());
    const ids = new SequentialUuidV7Generator();
    const app = createApp({
      overrides: { clock, idGenerator: ids, logger: new RecordingLogger() },
    });
    const env = buildE2eEnv(h, {
      CLOUD_MEDIA_QUOTA_PER_APARTMENT: '2',
      INVITE_CODE_RATE_LIMIT_MAX_ATTEMPTS: '2',
      INVITE_CODE_RATE_LIMIT_WINDOW_SECONDS: '60',
    });
    const c = createE2eClient((req) => app.fetch(req, env));
    const owner = 'dev:qrd-owner:Krzysztof';
    const contrib1 = 'dev:qrd-contrib1:Marek';
    const contrib2 = 'dev:qrd-contrib2:Zofia';
    const brute = 'dev:qrd-brute:Bot';

    const c1 = UserProfileSchema.parse(await jsonOf(c, '/v1/me', contrib1));
    const c2 = UserProfileSchema.parse(await jsonOf(c, '/v1/me', contrib2));
    const sharedId = ids.nextId();
    const sharedApt = await putApartment(c, owner, sharedId, {
      name: 'Shared',
      street: 'Długa 5',
      city: 'Kraków',
    });
    const joinWith = (token: string, inviteCode: string) =>
      c.request('/v1/apartments/join', { method: 'POST', token, json: { inviteCode } });
    expect((await joinWith(contrib1, sharedApt.inviteCode ?? '')).status).toBe(HTTP_STATUS.OK);
    expect((await joinWith(contrib2, sharedApt.inviteCode ?? '')).status).toBe(HTTP_STATUS.OK);

    const addPhotoAndNote = async (token: string, a: number, b: number, text: string) => {
      const mediaId = ids.nextId();
      const entryId = ids.nextId();
      await uploadPhoto(c, {
        token,
        apartmentId: sharedId,
        mediaId,
        bytes: makeJpegBytes(a, b),
        capturedAt: clock.nowIso(),
      });
      await putEntry(c, {
        token,
        apartmentId: sharedId,
        mediaId,
        entryId,
        text,
        createdAt: clock.nowIso(),
      });
      return { mediaId, entryId };
    };
    const { mediaId: ownerPhotoId, entryId: ownerEntryId } = await addPhotoAndNote(
      owner,
      1,
      2,
      'Owner note',
    );
    const { mediaId: c2PhotoId, entryId: c2EntryId } = await addPhotoAndNote(
      contrib2,
      3,
      4,
      'Zofia note',
    );

    await c.request(`/v1/apartments/${sharedId}/media/${ownerPhotoId}`, {
      method: 'DELETE',
      token: owner,
    });
    const quotaRes = await initMediaRaw(
      c,
      owner,
      sharedId,
      ids.nextId(),
      makeJpegBytes(5, 6),
      clock.nowIso(),
    );
    expect(quotaRes.status).toBe(HTTP_STATUS.UNPROCESSABLE_ENTITY);
    expect(quotaRes.headers.get('content-type')).toContain('application/problem+json');
    expect(ProblemDetailsSchema.parse(await quotaRes.json()).code).toBe(
      MEDIA_ERROR_CODES.QUOTA_EXCEEDED,
    );

    await joinWith(brute, 'XXXX-YYYY');
    await joinWith(brute, 'XXXX-YYYY');
    const rateRes = await joinWith(brute, 'XXXX-YYYY');
    expect(rateRes.status).toBe(HTTP_STATUS.TOO_MANY_REQUESTS);
    expect(ProblemDetailsSchema.parse(await rateRes.json()).code).toBe(
      MEMBERSHIP_ERROR_CODES.INVITE_CODE_RATE_LIMITED,
    );

    expect(
      (
        await c.request(`/v1/apartments/${sharedId}/members/${c2.id}`, {
          method: 'DELETE',
          token: owner,
        })
      ).status,
    ).toBe(HTTP_STATUS.NO_CONTENT);
    expect((await c.request(`/v1/apartments/${sharedId}`, { token: contrib2 })).status).toBe(
      HTTP_STATUS.FORBIDDEN,
    );
    const blockedWrite = await c.request(
      `/v1/apartments/${sharedId}/media/${c2PhotoId}/entries/${ids.nextId()}`,
      {
        method: 'PUT',
        token: contrib2,
        json: { text: 'Blocked', createdAt: clock.nowIso(), markers: [] },
      },
    );
    expect(blockedWrite.status).toBe(HTTP_STATUS.FORBIDDEN);
    expect((await joinWith(contrib2, sharedApt.inviteCode ?? '')).status).toBe(
      HTTP_STATUS.FORBIDDEN,
    );

    const c2Entries = EntryListResponseSchema.parse(
      await jsonOf(c, `/v1/apartments/${sharedId}/media/${c2PhotoId}/entries`, contrib1),
    );
    expect(c2Entries.items.some((e) => e.id === c2EntryId && e.text === 'Zofia note')).toBe(true);

    const privateId = ids.nextId();
    const privatePhotoId = ids.nextId();
    await putApartment(c, owner, privateId, {
      name: 'Private',
      street: 'Słoneczna 1',
      city: 'Sopot',
    });
    await uploadPhoto(c, {
      token: owner,
      apartmentId: privateId,
      mediaId: privatePhotoId,
      bytes: makeJpegBytes(7, 8),
      capturedAt: clock.nowIso(),
    });
    const privateR2Key = buildMediaR2Key(privateId, privatePhotoId);
    expect(await h.r2.head(privateR2Key)).not.toBeNull();

    expect((await c.request('/v1/me', { method: 'DELETE', token: owner })).status).toBe(
      HTTP_STATUS.NO_CONTENT,
    );
    const privRow = await queryFirst(
      h.db,
      createStatement('SELECT id FROM apartments WHERE id = ?', [privateId]),
      idRowSchema,
    );
    expect(privRow.ok && privRow.value).toBeNull();
    expect(await h.r2.head(privateR2Key)).toBeNull();

    expect(
      ApartmentDtoSchema.parse(await jsonOf(c, `/v1/apartments/${sharedId}`, contrib1)).ownerId,
    ).toBe(c1.id);
    const members = ApartmentMemberListResponseSchema.parse(
      await jsonOf(c, `/v1/apartments/${sharedId}/members`, contrib1),
    );
    expect(members.items.find((m) => m.userId === c1.id)?.role).toBe('owner');
    const timeline = MediaTimelineResponseSchema.parse(
      await jsonOf(c, `/v1/apartments/${sharedId}/media`, contrib1),
    );
    expect(timeline.items.find((m) => m.id === ownerPhotoId)?.author.displayName).toBe(
      DELETED_USER_DISPLAY_NAME,
    );
    const ownerEntries = EntryListResponseSchema.parse(
      await jsonOf(c, `/v1/apartments/${sharedId}/media/${ownerPhotoId}/entries`, contrib1),
    );
    expect(ownerEntries.items.find((e) => e.id === ownerEntryId)?.author.displayName).toBe(
      DELETED_USER_DISPLAY_NAME,
    );

    const deletedMe = await c.request('/v1/me', { token: owner });
    expect(deletedMe.status).toBe(HTTP_STATUS.FORBIDDEN);
    expect(ProblemDetailsSchema.parse(await deletedMe.json()).code).toBe(
      IDENTITY_ERROR_CODES.USER_DELETED,
    );
  });
});
