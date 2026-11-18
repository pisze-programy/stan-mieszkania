import { createStatement, execute, queryFirst } from '@stanmieszkania/d1';
import { HTTP_STATUS, ProblemDetailsSchema } from '@stanmieszkania/http-contracts';
import { days, isOk } from '@stanmieszkania/shared';
import { FixedClock, RecordingLogger, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { z } from 'zod';
import { createApp } from '../../../app';
import { createD1TestHarness, type D1TestHarness } from '../../../testing/d1-test-harness';
import { ApartmentDtoSchema, ORPHAN_APARTMENT_RETENTION_DAYS } from '../../apartments';
import { DELETED_USER_DISPLAY_NAME, IDENTITY_ERROR_CODES } from '../../identity';
import { ApartmentMemberListResponseSchema } from '../../membership';
import {
  RecordingAppleTokenRevoker,
  RecordingIdentityProviderDeleter,
} from '../testing/in-memory-account-deletion.doubles';

describe('DELETE /v1/me end-to-end (Miniflare D1 + R2 + UserGuard DO)', () => {
  let harness: D1TestHarness | undefined;

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

  it('hard-deletes private apartment and R2 media, transfers/orphans shared apartments, anonymizes member, and blocks JWT with 403', async () => {
    const clock = new FixedClock('2026-11-18T12:00:00.000Z');
    const ids = new SequentialUuidV7Generator();
    const appleRevoker = new RecordingAppleTokenRevoker();
    const providerDeleter = new RecordingIdentityProviderDeleter();
    const app = createApp({
      overrides: {
        clock,
        idGenerator: ids,
        logger: new RecordingLogger(),
        appleTokenRevoker: appleRevoker,
        identityProviderDeleter: providerDeleter,
      },
    });
    const env = {
      DB: getHarness().db,
      MEDIA_BUCKET: getHarness().r2,
      USER_GUARD: getHarness().userGuard,
      AUTH_MODE: 'local',
    };

    const ownerAuth = {
      Authorization: 'Bearer dev:owner-del:Anna',
      'content-type': 'application/json',
    };
    const contribAuth = {
      Authorization: 'Bearer dev:contrib-1:Piotr',
      'content-type': 'application/json',
    };
    const formerAuth = {
      Authorization: 'Bearer dev:contrib-former:Ewa',
      'content-type': 'application/json',
    };

    const createApt = async (auth: Record<string, string>, name: string) => {
      const id = ids.nextId();
      const res = await app.request(
        `/v1/apartments/${id}`,
        {
          method: 'PUT',
          headers: auth,
          body: JSON.stringify({ name, street: 'Main 1', city: 'Warsaw' }),
        },
        env,
      );
      expect(res.status).toBe(HTTP_STATUS.OK);
      return ApartmentDtoSchema.parse(await res.json());
    };

    const privateApt = await createApt(ownerAuth, 'Private Flat');
    const transferApt = await createApt(ownerAuth, 'Shared Transfer Flat');
    const orphanApt = await createApt(ownerAuth, 'Shared Orphan Flat');

    const privateKey = `${privateApt.id}/photo-1.jpg`;
    await getHarness().r2.put(privateKey, 'private-jpeg');
    const insertMedia = await execute(
      getHarness().db,
      createStatement(
        'INSERT INTO media (id, apartment_id, author_id, kind, source, upload_status, sha256, captured_at, captured_tz, width, height, bytes, r2_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          ids.nextId(),
          privateApt.id,
          privateApt.ownerId,
          'photo',
          'camera',
          'confirmed',
          'a'.repeat(64),
          clock.nowIso(),
          'Europe/Warsaw',
          1200,
          800,
          12345,
          privateKey,
        ],
      ),
    );
    expect(insertMedia.ok).toBe(true);

    clock.advanceBy(1_000);
    const joinTransfer = await app.request(
      '/v1/apartments/join',
      {
        method: 'POST',
        headers: contribAuth,
        body: JSON.stringify({ inviteCode: transferApt.inviteCode }),
      },
      env,
    );
    expect(joinTransfer.status).toBe(HTTP_STATUS.OK);

    const joinOrphan = await app.request(
      '/v1/apartments/join',
      {
        method: 'POST',
        headers: formerAuth,
        body: JSON.stringify({ inviteCode: orphanApt.inviteCode }),
      },
      env,
    );
    expect(joinOrphan.status).toBe(HTTP_STATUS.OK);
    const leaveOrphan = await app.request(
      `/v1/apartments/${orphanApt.id}/leave`,
      { method: 'POST', headers: formerAuth },
      env,
    );
    expect(leaveOrphan.status).toBe(HTTP_STATUS.NO_CONTENT);

    clock.advanceBy(5_000);
    const deleteAtMs = clock.nowMs();
    const deleteRes = await app.request(
      '/v1/me',
      {
        method: 'DELETE',
        headers: ownerAuth,
        body: JSON.stringify({ appleAuthorizationCode: 'apple-code-123' }),
      },
      env,
    );
    expect(deleteRes.status).toBe(HTTP_STATUS.NO_CONTENT);
    expect(appleRevoker.revokedCodes).toEqual(['apple-code-123']);
    expect(providerDeleter.deletedFirebaseUids).toEqual(['owner-del']);

    const privateRow = await queryFirst(
      getHarness().db,
      createStatement('SELECT id FROM apartments WHERE id = ?', [privateApt.id]),
      z.object({ id: z.string() }),
    );
    expect(privateRow).toEqual({ ok: true, value: null });
    expect(await getHarness().r2.get(privateKey)).toBeNull();

    const membersRes = await app.request(
      `/v1/apartments/${transferApt.id}/members`,
      { headers: contribAuth },
      env,
    );
    expect(membersRes.status).toBe(HTTP_STATUS.OK);
    const { items } = ApartmentMemberListResponseSchema.parse(await membersRes.json());
    expect(items.find((member) => member.displayName === 'Piotr')?.role).toBe('owner');
    const anonymized = items.find((member) => member.userId === privateApt.ownerId);
    expect(anonymized?.displayName).toBe(DELETED_USER_DISPLAY_NAME);
    expect(anonymized?.leftAt).toBe(clock.nowIso());

    const orphanRow = await queryFirst(
      getHarness().db,
      createStatement('SELECT orphan_delete_after FROM apartments WHERE id = ?', [orphanApt.id]),
      z.object({ orphan_delete_after: z.string().nullable() }),
    );
    expect(isOk(orphanRow)).toBe(true);
    if (isOk(orphanRow)) {
      expect(orphanRow.value?.orphan_delete_after).toBe(
        new Date(deleteAtMs + days(ORPHAN_APARTMENT_RETENTION_DAYS)).toISOString(),
      );
    }

    const blockedRes = await app.request('/v1/me', { headers: ownerAuth }, env);
    expect(blockedRes.status).toBe(HTTP_STATUS.FORBIDDEN);
    expect(ProblemDetailsSchema.parse(await blockedRes.json()).code).toBe(
      IDENTITY_ERROR_CODES.USER_DELETED,
    );
  });

  it('accepts DELETE /v1/me without a JSON body', async () => {
    const app = createApp({
      overrides: {
        clock: new FixedClock('2026-11-18T13:00:00.000Z'),
        idGenerator: new SequentialUuidV7Generator(),
        logger: new RecordingLogger(),
      },
    });
    const env = {
      DB: getHarness().db,
      MEDIA_BUCKET: getHarness().r2,
      USER_GUARD: getHarness().userGuard,
      AUTH_MODE: 'local',
    };
    const headers = { Authorization: 'Bearer dev:empty-body-user:Marek' };

    expect((await app.request('/v1/me', { headers }, env)).status).toBe(HTTP_STATUS.OK);
    expect((await app.request('/v1/me', { method: 'DELETE', headers }, env)).status).toBe(
      HTTP_STATUS.NO_CONTENT,
    );
    expect((await app.request('/v1/me', { headers }, env)).status).toBe(HTTP_STATUS.FORBIDDEN);
  });
});
