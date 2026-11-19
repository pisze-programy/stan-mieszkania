import {
  ABANDONED_CLEANUP_DELETE_MEDIA_INDEX,
  MEDIA_ABANDONED_CLEANED_OP,
  MEDIA_ENTITY_TYPE,
  MEDIA_PENDING_OP,
  ORPHAN_PURGE_RETRY_DELAY_MS,
  UPLOAD_STATUS_PENDING,
} from './apartment-coordinator.constants';
import type {
  ApartmentCoordinatorEnv,
  CoordinatorD1DatabaseLike,
  CoordinatorD1PreparedStatementLike,
  CoordinatorPersistedState,
  MaintenanceRunResult,
} from './apartment-coordinator.types';

interface ApartmentOrphanRow {
  readonly id: string;
  readonly orphan_delete_after: string | null;
}

interface MediaR2KeyRow {
  readonly r2_key: string;
}

interface AbandonedMediaRow {
  readonly id: string;
  readonly r2_key: string;
}

interface EarliestPendingRow {
  readonly earliest_pending_at: string | null;
}

function hardDeleteApartmentBatch<
  TStatement extends CoordinatorD1PreparedStatementLike<TStatement>,
>(db: CoordinatorD1DatabaseLike<TStatement>, apartmentId: string): TStatement[] {
  return [
    db
      .prepare(
        'DELETE FROM markers WHERE media_id IN (SELECT id FROM media WHERE apartment_id = ?)',
      )
      .bind(apartmentId),
    db
      .prepare(
        'DELETE FROM entries WHERE media_id IN (SELECT id FROM media WHERE apartment_id = ?)',
      )
      .bind(apartmentId),
    db.prepare('DELETE FROM media WHERE apartment_id = ?').bind(apartmentId),
    db.prepare('DELETE FROM apartment_changes WHERE apartment_id = ?').bind(apartmentId),
    db.prepare('DELETE FROM memberships WHERE apartment_id = ?').bind(apartmentId),
    db.prepare('DELETE FROM change_log WHERE apartment_id = ?').bind(apartmentId),
    db.prepare('DELETE FROM apartments WHERE id = ?').bind(apartmentId),
  ];
}

function reclaimAbandonedPendingBatch<
  TStatement extends CoordinatorD1PreparedStatementLike<TStatement>,
>(
  db: CoordinatorD1DatabaseLike<TStatement>,
  apartmentId: string,
  mediaId: string,
  nowIso: string,
): TStatement[] {
  const pendingGuard =
    'EXISTS (SELECT 1 FROM media WHERE id = ? AND apartment_id = ? AND upload_status = ? AND deleted_at IS NULL)';
  return [
    db
      .prepare(
        `UPDATE apartments SET cloud_media_count = CASE WHEN cloud_media_count > 0 THEN cloud_media_count - 1 ELSE 0 END, updated_at = ? WHERE id = ? AND deleted_at IS NULL AND ${pendingGuard}`,
      )
      .bind(nowIso, apartmentId, mediaId, apartmentId, UPLOAD_STATUS_PENDING),
    db
      .prepare(
        `INSERT INTO change_log (apartment_id, entity_type, entity_id, op, created_at) SELECT ?, ?, ?, ?, ? WHERE ${pendingGuard}`,
      )
      .bind(
        apartmentId,
        MEDIA_ENTITY_TYPE,
        mediaId,
        MEDIA_ABANDONED_CLEANED_OP,
        nowIso,
        mediaId,
        apartmentId,
        UPLOAD_STATUS_PENDING,
      ),
    db
      .prepare(`DELETE FROM markers WHERE media_id = ? AND ${pendingGuard}`)
      .bind(mediaId, mediaId, apartmentId, UPLOAD_STATUS_PENDING),
    db
      .prepare(`DELETE FROM entries WHERE media_id = ? AND ${pendingGuard}`)
      .bind(mediaId, mediaId, apartmentId, UPLOAD_STATUS_PENDING),
    db
      .prepare(
        'DELETE FROM media WHERE id = ? AND apartment_id = ? AND upload_status = ? AND deleted_at IS NULL',
      )
      .bind(mediaId, apartmentId, UPLOAD_STATUS_PENDING),
  ];
}

function computeNextAlarmMs(
  orphanDeleteAfter: string | null,
  earliestPendingAt: string | null,
  ttlMs: number,
): number | null {
  const candidates: number[] = [];
  if (orphanDeleteAfter !== null) {
    const parsed = Date.parse(orphanDeleteAfter);
    if (Number.isFinite(parsed)) {
      candidates.push(parsed);
    }
  }
  if (earliestPendingAt !== null) {
    const parsed = Date.parse(earliestPendingAt);
    if (Number.isFinite(parsed)) {
      candidates.push(parsed + ttlMs);
    }
  }
  return candidates.length === 0 ? null : Math.min(...candidates);
}

// Decision Q5 & A17: Purge expired 30-day orphaned apartments and reclaim abandoned pending upload slots atomically.
export async function executeApartmentMaintenance<
  TStatement extends CoordinatorD1PreparedStatementLike<TStatement>,
>(
  env: ApartmentCoordinatorEnv<TStatement>,
  state: CoordinatorPersistedState,
  nowMs: number,
): Promise<MaintenanceRunResult> {
  const db = env.DB;
  if (db === undefined) {
    return { apartmentPurged: false, cleanedPendingMediaCount: 0, nextAlarmMs: null };
  }

  const apartmentResult = await db
    .prepare(
      'SELECT id, orphan_delete_after FROM apartments WHERE id = ? AND deleted_at IS NULL LIMIT 1',
    )
    .bind(state.apartmentId)
    .all<ApartmentOrphanRow>();
  const apartment = apartmentResult.results[0];
  if (apartment === undefined) {
    return { apartmentPurged: false, cleanedPendingMediaCount: 0, nextAlarmMs: null };
  }

  if (
    apartment.orphan_delete_after !== null &&
    Date.parse(apartment.orphan_delete_after) <= nowMs
  ) {
    const mediaKeysResult = await db
      .prepare('SELECT r2_key FROM media WHERE apartment_id = ?')
      .bind(state.apartmentId)
      .all<MediaR2KeyRow>();
    try {
      for (const mediaRow of mediaKeysResult.results) {
        await env.MEDIA_BUCKET?.delete(mediaRow.r2_key);
      }
    } catch {
      return {
        apartmentPurged: false,
        cleanedPendingMediaCount: 0,
        nextAlarmMs: nowMs + ORPHAN_PURGE_RETRY_DELAY_MS,
      };
    }

    await db.batch(hardDeleteApartmentBatch(db, state.apartmentId));
    return { apartmentPurged: true, cleanedPendingMediaCount: 0, nextAlarmMs: null };
  }

  const cutoffIso = new Date(nowMs - state.abandonedPendingUploadTtlMs).toISOString();
  const nowIso = new Date(nowMs).toISOString();
  const abandonedResult = await db
    .prepare(
      'SELECT m.id, m.r2_key FROM media m WHERE m.apartment_id = ? AND m.upload_status = ? AND m.deleted_at IS NULL AND COALESCE((SELECT MIN(cl.created_at) FROM change_log cl WHERE cl.apartment_id = m.apartment_id AND cl.entity_type = ? AND cl.entity_id = m.id AND cl.op = ?), m.captured_at) <= ? ORDER BY m.id ASC',
    )
    .bind(state.apartmentId, UPLOAD_STATUS_PENDING, MEDIA_ENTITY_TYPE, MEDIA_PENDING_OP, cutoffIso)
    .all<AbandonedMediaRow>();

  let cleanedPendingMediaCount = 0;
  for (const row of abandonedResult.results) {
    try {
      await env.MEDIA_BUCKET?.delete(row.r2_key);
    } catch {
      continue;
    }

    const batchResults = await db.batch(
      reclaimAbandonedPendingBatch(db, state.apartmentId, row.id, nowIso),
    );
    if ((batchResults[ABANDONED_CLEANUP_DELETE_MEDIA_INDEX]?.meta.changes ?? 0) === 1) {
      cleanedPendingMediaCount += 1;
    }
  }

  const remainingPending = await db
    .prepare(
      'SELECT MIN(COALESCE((SELECT MIN(cl.created_at) FROM change_log cl WHERE cl.apartment_id = m.apartment_id AND cl.entity_type = ? AND cl.entity_id = m.id AND cl.op = ?), m.captured_at)) AS earliest_pending_at FROM media m WHERE m.apartment_id = ? AND m.upload_status = ? AND m.deleted_at IS NULL',
    )
    .bind(MEDIA_ENTITY_TYPE, MEDIA_PENDING_OP, state.apartmentId, UPLOAD_STATUS_PENDING)
    .all<EarliestPendingRow>();

  const rawNextAlarmMs = computeNextAlarmMs(
    apartment.orphan_delete_after,
    remainingPending.results[0]?.earliest_pending_at ?? null,
    state.abandonedPendingUploadTtlMs,
  );
  const nextAlarmMs =
    rawNextAlarmMs === null ? null : Math.max(rawNextAlarmMs, nowMs + ORPHAN_PURGE_RETRY_DELAY_MS);

  return { apartmentPurged: false, cleanedPendingMediaCount, nextAlarmMs };
}
