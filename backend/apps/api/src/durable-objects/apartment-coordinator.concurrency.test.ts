import { createStatement, execute, queryFirst } from '@stanmieszkania/d1';
import { HTTP_STATUS, ProblemDetailsSchema } from '@stanmieszkania/http-contracts';
import { FixedClock, RecordingLogger, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { z } from 'zod';
import { createApp } from '../app';
import { ApartmentDtoSchema } from '../modules/apartments';
import { EntryDtoSchema } from '../modules/entries';
import { MEDIA_ERROR_CODES } from '../modules/media';
import { createD1TestHarness, type D1TestHarness } from '../testing/d1-test-harness';

const authHeaders = (token: string) => ({
  Authorization: `Bearer ${token}`,
  'content-type': 'application/json',
});

const countRowSchema = z.object({ cloud_media_count: z.number() });

describe('ApartmentCoordinator DO mutation serialization (Miniflare D1 + R2 + DO)', () => {
  let harness: D1TestHarness | undefined;
  const ids = new SequentialUuidV7Generator();
  const getHarness = (): D1TestHarness => {
    if (harness === undefined) {
      throw new Error('D1 test harness was not initialized');
    }
    return harness;
  };

  beforeAll(async () => {
    harness = await createD1TestHarness();
  });

  afterAll(async () => {
    await harness?.dispose();
  });

  it('serializes parallel createEntry requests on the same photo into sequential [1],[2],[3] markers', async () => {
    const clock = new FixedClock('2026-11-18T16:00:00.000Z');
    const app = createApp({
      overrides: { clock, idGenerator: ids, logger: new RecordingLogger() },
    });
    const env = {
      DB: getHarness().db,
      MEDIA_BUCKET: getHarness().r2,
      USER_GUARD: getHarness().userGuard,
      APARTMENT_COORDINATOR: getHarness().apartmentCoordinator,
      AUTH_MODE: 'local',
    };
    const ownerAuth = authHeaders('dev:conc-entry-owner:Anna');
    const contribAuth = authHeaders('dev:conc-entry-contrib:Piotr');

    const aptId = ids.nextId();
    const aptRes = await app.request(
      `/v1/apartments/${aptId}`,
      {
        method: 'PUT',
        headers: ownerAuth,
        body: JSON.stringify({ name: 'Race Test Flat', street: 'Main 1', city: 'Warsaw' }),
      },
      env,
    );
    expect(aptRes.status).toBe(HTTP_STATUS.OK);
    const apt = ApartmentDtoSchema.parse(await aptRes.json());

    const joinRes = await app.request(
      '/v1/apartments/join',
      {
        method: 'POST',
        headers: contribAuth,
        body: JSON.stringify({ inviteCode: apt.inviteCode }),
      },
      env,
    );
    expect(joinRes.status).toBe(HTTP_STATUS.OK);

    const mediaId = ids.nextId();
    const seeded = await execute(
      getHarness().db,
      createStatement(
        'INSERT INTO media (id, apartment_id, author_id, kind, source, upload_status, sha256, captured_at, captured_tz, width, height, bytes, r2_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          mediaId,
          apt.id,
          apt.ownerId,
          'photo',
          'camera',
          'confirmed',
          'a'.repeat(64),
          clock.nowIso(),
          'Europe/Warsaw',
          1200,
          800,
          2048,
          `apartments/${apt.id}/media/${mediaId}.jpg`,
        ],
      ),
    );
    expect(seeded.ok).toBe(true);

    const requests = [
      { entryId: ids.nextId(), markerId: ids.nextId(), auth: ownerAuth, text: 'Crack [1]' },
      { entryId: ids.nextId(), markerId: ids.nextId(), auth: contribAuth, text: 'Stain [1]' },
      { entryId: ids.nextId(), markerId: ids.nextId(), auth: ownerAuth, text: 'Dent [1]' },
    ];

    const responses = await Promise.all(
      requests.map(async (req) =>
        app.request(
          `/v1/apartments/${apt.id}/media/${mediaId}/entries/${req.entryId}`,
          {
            method: 'PUT',
            headers: req.auth,
            body: JSON.stringify({
              text: req.text,
              createdAt: clock.nowIso(),
              markers: [{ id: req.markerId, localNumber: 1, x: 0.25, y: 0.75 }],
            }),
          },
          env,
        ),
      ),
    );

    expect(responses.map((res) => res.status)).toEqual([
      HTTP_STATUS.OK,
      HTTP_STATUS.OK,
      HTTP_STATUS.OK,
    ]);
    const parsedEntries = await Promise.all(
      responses.map(async (res) => EntryDtoSchema.parse(await res.json())),
    );
    const assignedNumbers = parsedEntries
      .map((entry) => entry.markers[0]?.number)
      .sort((left, right) => (left ?? 0) - (right ?? 0));
    expect(assignedNumbers).toEqual([1, 2, 3]);
  });

  it('enforces exact cloudMediaQuota under parallel initMediaUpload requests without oversubscription', async () => {
    const clock = new FixedClock(new Date(Date.now() + 7 * 86_400_000).toISOString());
    const app = createApp({
      overrides: { clock, idGenerator: ids, logger: new RecordingLogger() },
    });
    const env = {
      DB: getHarness().db,
      MEDIA_BUCKET: getHarness().r2,
      USER_GUARD: getHarness().userGuard,
      APARTMENT_COORDINATOR: getHarness().apartmentCoordinator,
      AUTH_MODE: 'local',
      STORAGE_MODE: 'local',
      CLOUD_MEDIA_QUOTA_PER_APARTMENT: '2',
    };
    const ownerAuth = authHeaders('dev:conc-quota-owner:Kasia');

    const aptId = ids.nextId();
    const aptRes = await app.request(
      `/v1/apartments/${aptId}`,
      {
        method: 'PUT',
        headers: ownerAuth,
        body: JSON.stringify({ name: 'Quota Flat', street: 'Oak 2', city: 'Krakow' }),
      },
      env,
    );
    expect(aptRes.status).toBe(HTTP_STATUS.OK);

    const mediaIds = Array.from({ length: 5 }, () => ids.nextId());
    const responses = await Promise.all(
      mediaIds.map(async (mediaId, idx) =>
        app.request(
          `/v1/apartments/${aptId}/media/${mediaId}/init`,
          {
            method: 'POST',
            headers: ownerAuth,
            body: JSON.stringify({
              kind: 'photo',
              source: 'camera',
              sha256: String(idx + 1).repeat(64),
              capturedAt: clock.nowIso(),
              capturedTz: 'Europe/Warsaw',
              width: 1000,
              height: 800,
              bytes: 1024,
            }),
          },
          env,
        ),
      ),
    );

    const okResponses = responses.filter((res) => res.status === HTTP_STATUS.OK);
    const rejectedResponses = responses.filter(
      (res) => res.status === HTTP_STATUS.UNPROCESSABLE_ENTITY,
    );
    expect(okResponses).toHaveLength(2);
    expect(rejectedResponses).toHaveLength(3);

    for (const rejected of rejectedResponses) {
      const problem = ProblemDetailsSchema.parse(await rejected.json());
      expect(problem.code).toBe(MEDIA_ERROR_CODES.QUOTA_EXCEEDED);
    }

    const row = await queryFirst(
      getHarness().db,
      createStatement('SELECT cloud_media_count FROM apartments WHERE id = ?', [aptId]),
      countRowSchema,
    );
    expect(row.ok && row.value?.cloud_media_count).toBe(2);
  });
});
