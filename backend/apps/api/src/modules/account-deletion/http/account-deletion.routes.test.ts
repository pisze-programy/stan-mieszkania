import { createStatement, execute, query, queryFirst } from '@stanmieszkania/d1';
import { HTTP_STATUS, ProblemDetailsSchema } from '@stanmieszkania/http-contracts';
import { days, isOk } from '@stanmieszkania/shared';
import { FixedClock, RecordingLogger, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { z } from 'zod';
import { createApp } from '../../../app';
import { createD1TestHarness, type D1TestHarness } from '../../../testing/d1-test-harness';
import {
  ApartmentDtoSchema,
  CHANGE_LOG_ENTITY_TYPES,
  CHANGE_LOG_OPS,
  ORPHAN_APARTMENT_RETENTION_DAYS,
} from '../../apartments';
import { DELETED_USER_DISPLAY_NAME, IDENTITY_ERROR_CODES } from '../../identity';
import { ApartmentMemberListResponseSchema } from '../../membership';
import {
  RecordingAppleTokenRevoker,
  RecordingIdentityProviderDeleter,
} from '../testing/in-memory-account-deletion.doubles';

const changeLogRowSchema = z.object({
  entity_type: z.string(),
  entity_id: z.string(),
  op: z.string(),
});

const authHeaders = (token: string) => ({
  Authorization: `Bearer ${token}`,
  'content-type': 'application/json',
});

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

  it('purges private apartment/R2, transfers/orphans shared apartments with aligned change_log, and blocks JWT with 403', async () => {
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
    const ownerAuth = authHeaders('dev:owner-del:Anna');
    const contribAuth = authHeaders('dev:contrib-1:Piotr');
    const formerAuth = authHeaders('dev:contrib-former:Ewa');

    const createApt = async (headers: Record<string, string>, name: string) => {
      const res = await app.request(
        `/v1/apartments/${ids.nextId()}`,
        {
          method: 'PUT',
          headers,
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
    const contribApt = await createApt(contribAuth, 'Piotr Flat');

    const privateKey = `${privateApt.id}/photo-1.jpg`;
    await getHarness().r2.put(privateKey, 'private-jpeg');
    const mediaSql =
      'INSERT INTO media (id, apartment_id, author_id, kind, source, upload_status, sha256, captured_at, captured_tz, width, height, bytes, r2_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
    const mediaParams = [
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
    ];
    expect((await execute(getHarness().db, createStatement(mediaSql, mediaParams))).ok).toBe(true);

    clock.advanceBy(1_000);
    for (const [headers, inviteCode] of [
      [contribAuth, transferApt.inviteCode],
      [formerAuth, orphanApt.inviteCode],
      [ownerAuth, contribApt.inviteCode],
    ] as const) {
      const res = await app.request(
        '/v1/apartments/join',
        { method: 'POST', headers, body: JSON.stringify({ inviteCode }) },
        env,
      );
      expect(res.status).toBe(HTTP_STATUS.OK);
    }
    const leaveRes = await app.request(
      `/v1/apartments/${orphanApt.id}/leave`,
      { method: 'POST', headers: formerAuth },
      env,
    );
    expect(leaveRes.status).toBe(HTTP_STATUS.NO_CONTENT);

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

    expect(
      await queryFirst(
        getHarness().db,
        createStatement('SELECT id FROM apartments WHERE id = ?', [privateApt.id]),
        z.object({ id: z.string() }),
      ),
    ).toEqual({ ok: true, value: null });
    expect(await getHarness().r2.get(privateKey)).toBeNull();

    const membersRes = await app.request(
      `/v1/apartments/${transferApt.id}/members`,
      { headers: contribAuth },
      env,
    );
    const { items } = ApartmentMemberListResponseSchema.parse(await membersRes.json());
    const piotr = items.find((member) => member.displayName === 'Piotr');
    expect(piotr?.role).toBe('owner');
    const anonymized = items.find((member) => member.userId === privateApt.ownerId);
    expect(anonymized?.displayName).toBe(DELETED_USER_DISPLAY_NAME);
    expect(anonymized?.leftAt).toBe(clock.nowIso());

    const readLogs = (aptId: string) =>
      query(
        getHarness().db,
        createStatement(
          'SELECT entity_type, entity_id, op FROM change_log WHERE apartment_id = ? ORDER BY seq ASC',
          [aptId],
        ),
        changeLogRowSchema,
      );

    const logEntry = (entityType: string, entityId: string | undefined, op: string) => ({
      entity_type: entityType,
      entity_id: entityId,
      op,
    });
    const transferLogs = await readLogs(transferApt.id);
    expect(isOk(transferLogs) ? transferLogs.value.slice(-3) : []).toEqual([
      logEntry(
        CHANGE_LOG_ENTITY_TYPES.APARTMENT,
        transferApt.id,
        CHANGE_LOG_OPS.OWNERSHIP_TRANSFERRED,
      ),
      logEntry(CHANGE_LOG_ENTITY_TYPES.MEMBERSHIP, privateApt.ownerId, CHANGE_LOG_OPS.LEFT),
      logEntry(CHANGE_LOG_ENTITY_TYPES.MEMBERSHIP, piotr?.userId, CHANGE_LOG_OPS.PROMOTED),
    ]);

    const contribLogs = await readLogs(contribApt.id);
    expect(isOk(contribLogs) ? contribLogs.value.at(-1) : undefined).toEqual(
      logEntry(CHANGE_LOG_ENTITY_TYPES.MEMBERSHIP, privateApt.ownerId, CHANGE_LOG_OPS.LEFT),
    );

    const orphanRow = await queryFirst(
      getHarness().db,
      createStatement('SELECT orphan_delete_after FROM apartments WHERE id = ?', [orphanApt.id]),
      z.object({ orphan_delete_after: z.string().nullable() }),
    );
    expect(isOk(orphanRow) ? orphanRow.value?.orphan_delete_after : null).toBe(
      new Date(deleteAtMs + days(ORPHAN_APARTMENT_RETENTION_DAYS)).toISOString(),
    );

    const blockedRes = await app.request('/v1/me', { headers: ownerAuth }, env);
    expect(blockedRes.status).toBe(HTTP_STATUS.FORBIDDEN);
    expect(ProblemDetailsSchema.parse(await blockedRes.json()).code).toBe(
      IDENTITY_ERROR_CODES.USER_DELETED,
    );
  });
});
