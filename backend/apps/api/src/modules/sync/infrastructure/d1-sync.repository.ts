import {
  query,
  queryFirst,
  type D1Client,
  type D1PreparedStatementLike,
  type D1Queryable,
} from '@stanmieszkania/d1';
import { mapResult, ok, type DomainError, type Result } from '@stanmieszkania/shared';
import { SYNC_ENTITY_TYPES, SYNC_ROLES } from '../domain/sync.constants';
import type { SyncApartmentSnapshot, SyncMarkerSnapshot } from '../domain/sync.entity';
import type { SyncRepository } from '../domain/sync.repository';
import { CHANGE_LOG_TABLE, type ChangeLogRow } from './change-log.table';
import {
  mapApartmentHydrationRow,
  mapEntryHydrationRow,
  mapHydratedChange,
  mapMarkerRowToSyncSnapshot,
  mapMediaHydrationRow,
  mapMemberHydrationRow,
  mapMyApartmentSyncRow,
  type HydrationMaps,
} from './sync-hydration.mapper';
import {
  findApartmentForHydrationStatement,
  findSyncApartmentAccessStatement,
  listChangeLogAfterStatement,
  listEntriesForHydrationStatement,
  listMarkersForHydrationStatement,
  listMediaForHydrationStatement,
  listMembersForHydrationStatement,
  listMyApartmentsSyncStatement,
  markerRowSchema,
  myApartmentSyncRowSchema,
  syncApartmentAccessRowSchema,
  syncApartmentHydrationRowSchema,
  syncEntryHydrationRowSchema,
  syncMediaHydrationRowSchema,
  syncMemberHydrationRowSchema,
} from './sync.queries';

function collectIds(rows: readonly ChangeLogRow[], entityType: string): readonly string[] {
  const unique = new Set<string>();
  for (const row of rows) {
    if (row.entity_type === entityType) {
      unique.add(row.entity_id);
    }
  }
  return Array.from(unique);
}

async function hydrateChangeRows(
  db: D1Queryable,
  apartmentId: string,
  callerUserId: string,
  callerRole: 'owner' | 'contributor',
  rows: readonly ChangeLogRow[],
): Promise<Result<HydrationMaps, DomainError>> {
  const hasApartment = rows.some((r) => r.entity_type === SYNC_ENTITY_TYPES.APARTMENT);
  const memberIds = collectIds(rows, SYNC_ENTITY_TYPES.MEMBERSHIP);
  const mediaIds = collectIds(rows, SYNC_ENTITY_TYPES.MEDIA);
  const entryIds = collectIds(rows, SYNC_ENTITY_TYPES.ENTRY);

  let apartment: SyncApartmentSnapshot | null = null;
  if (hasApartment) {
    const aptRes = await queryFirst(
      db,
      findApartmentForHydrationStatement(apartmentId),
      syncApartmentHydrationRowSchema,
    );
    if (!aptRes.ok) return aptRes;
    apartment = aptRes.value === null ? null : mapApartmentHydrationRow(aptRes.value, callerRole);
  }

  const members = new Map<string, ReturnType<typeof mapMemberHydrationRow>>();
  if (memberIds.length > 0) {
    const memRes = await query(
      db,
      listMembersForHydrationStatement(apartmentId, memberIds),
      syncMemberHydrationRowSchema,
    );
    if (!memRes.ok) return memRes;
    for (const row of memRes.value) {
      members.set(row.user_id, mapMemberHydrationRow(row));
    }
  }

  const media = new Map<string, ReturnType<typeof mapMediaHydrationRow>>();
  if (mediaIds.length > 0) {
    const mediaRes = await query(
      db,
      listMediaForHydrationStatement(apartmentId, callerUserId, mediaIds),
      syncMediaHydrationRowSchema,
    );
    if (!mediaRes.ok) return mediaRes;
    for (const row of mediaRes.value) {
      media.set(row.id, mapMediaHydrationRow(row));
    }
  }

  const entries = new Map<string, ReturnType<typeof mapEntryHydrationRow>>();
  if (entryIds.length > 0) {
    const [entriesRes, markersRes] = await Promise.all([
      query(
        db,
        listEntriesForHydrationStatement(apartmentId, entryIds),
        syncEntryHydrationRowSchema,
      ),
      query(db, listMarkersForHydrationStatement(entryIds), markerRowSchema),
    ]);
    if (!entriesRes.ok) return entriesRes;
    if (!markersRes.ok) return markersRes;

    const markersByEntry = new Map<string, SyncMarkerSnapshot[]>();
    for (const markerRow of markersRes.value) {
      const list = markersByEntry.get(markerRow.entry_id) ?? [];
      list.push(mapMarkerRowToSyncSnapshot(markerRow));
      markersByEntry.set(markerRow.entry_id, list);
    }
    for (const entryRow of entriesRes.value) {
      entries.set(
        entryRow.id,
        mapEntryHydrationRow(entryRow, markersByEntry.get(entryRow.id) ?? []),
      );
    }
  }

  return ok({ apartment, members, media, entries });
}

export function createD1SyncRepository<TStatement extends D1PreparedStatementLike<TStatement>>(
  db: D1Client<TStatement> & D1Queryable,
): SyncRepository {
  return {
    findApartmentAccess: async (apartmentId, userId) => {
      const result = await queryFirst(
        db,
        findSyncApartmentAccessStatement(apartmentId, userId),
        syncApartmentAccessRowSchema,
      );
      return mapResult(result, (row) => {
        if (row === null) return null;
        return {
          apartmentId: row.id,
          role: row.role ?? SYNC_ROLES.CONTRIBUTOR,
          isActiveMember: row.role !== null,
        };
      });
    },
    listChangesAfter: async ({ apartmentId, callerUserId, callerRole, afterSeq, limit }) => {
      const logResult = await query(
        db,
        listChangeLogAfterStatement(apartmentId, afterSeq, limit),
        CHANGE_LOG_TABLE.rowSchema,
      );
      if (!logResult.ok) return logResult;

      const hasMore = logResult.value.length > limit;
      const pageRows = hasMore ? logResult.value.slice(0, limit) : logResult.value;
      const hydration = await hydrateChangeRows(
        db,
        apartmentId,
        callerUserId,
        callerRole,
        pageRows,
      );
      if (!hydration.ok) return hydration;

      const lastRow = pageRows[pageRows.length - 1];
      return ok({
        changes: pageRows.map((row) => mapHydratedChange(row, hydration.value)),
        nextSeq: lastRow !== undefined ? lastRow.seq : null,
        hasMore,
      });
    },
    listMyApartmentsSync: async (userId) => {
      const result = await query(
        db,
        listMyApartmentsSyncStatement(userId),
        myApartmentSyncRowSchema,
      );
      return mapResult(result, (rows) => rows.map(mapMyApartmentSyncRow));
    },
  };
}
