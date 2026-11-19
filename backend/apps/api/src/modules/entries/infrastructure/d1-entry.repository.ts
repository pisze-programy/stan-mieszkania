import {
  executeBatch,
  query,
  queryFirst,
  type D1Client,
  type D1PreparedStatementLike,
  type D1Queryable,
} from '@stanmieszkania/d1';
import { mapResult, ok } from '@stanmieszkania/shared';
import type { EntryRepository } from '../domain/entry.repository';
import type { Marker } from '../domain/marker.entity';
import {
  apartmentMembershipRowSchema,
  entryWithAuthorRowSchema,
  findApartmentMembershipStatement,
  findEntryByIdStatement,
  findEntryWithAuthorByIdStatement,
  findTargetMediaAccessStatement,
  getMaxMarkerNumberStatement,
  insertEntryWithMarkersStatements,
  listEntriesWithAuthorByMediaStatement,
  listMarkersByEntryIdStatement,
  listMarkersByMediaIdStatement,
  maxMarkerNumberRowSchema,
  retractEntryStatements,
  targetMediaAccessRowSchema,
} from './entries.queries';
import { ENTRIES_TABLE } from './entries.table';
import {
  mapEntryRowToEntity,
  mapEntryWithAuthorRowToEntity,
  mapMarkerRowToEntity,
} from './entry-row.mapper';
import { MARKERS_TABLE } from './markers.table';

export function createD1EntryRepository<TStatement extends D1PreparedStatementLike<TStatement>>(
  db: D1Client<TStatement> & D1Queryable,
): EntryRepository {
  return {
    findApartmentMembership: async (apartmentId, userId) => {
      const result = await queryFirst(
        db,
        findApartmentMembershipStatement(apartmentId, userId),
        apartmentMembershipRowSchema,
      );
      return mapResult(result, (row) =>
        row === null
          ? null
          : {
              apartmentId: row.apartment_id,
              isActiveMember: row.is_active_member === 1,
            },
      );
    },

    findTargetMediaAccess: async (mediaId, userId) => {
      const result = await queryFirst(
        db,
        findTargetMediaAccessStatement(mediaId, userId),
        targetMediaAccessRowSchema,
      );
      return mapResult(result, (row) =>
        row === null
          ? null
          : {
              mediaId: row.media_id,
              apartmentId: row.apartment_id,
              authorId: row.author_id,
              uploadStatus: row.upload_status === 'confirmed' ? 'uploaded' : 'pending',
              deletedAt: row.deleted_at,
              isActiveMember: row.is_active_member === 1,
            },
      );
    },

    findById: async (entryId) => {
      const entryResult = await queryFirst(
        db,
        findEntryByIdStatement(entryId),
        ENTRIES_TABLE.rowSchema,
      );
      if (!entryResult.ok || entryResult.value === null) {
        return entryResult.ok ? ok(null) : entryResult;
      }

      const markersResult = await query(
        db,
        listMarkersByEntryIdStatement(entryId),
        MARKERS_TABLE.rowSchema,
      );
      if (!markersResult.ok) {
        return markersResult;
      }

      return ok(
        mapEntryRowToEntity(entryResult.value, markersResult.value.map(mapMarkerRowToEntity)),
      );
    },

    findByIdWithAuthor: async (entryId) => {
      const entryResult = await queryFirst(
        db,
        findEntryWithAuthorByIdStatement(entryId),
        entryWithAuthorRowSchema,
      );
      if (!entryResult.ok || entryResult.value === null) {
        return entryResult.ok ? ok(null) : entryResult;
      }

      const markersResult = await query(
        db,
        listMarkersByEntryIdStatement(entryId),
        MARKERS_TABLE.rowSchema,
      );
      if (!markersResult.ok) {
        return markersResult;
      }

      return ok(
        mapEntryWithAuthorRowToEntity(
          entryResult.value,
          markersResult.value.map(mapMarkerRowToEntity),
        ),
      );
    },

    listByMedia: async (mediaId) => {
      const entriesResult = await query(
        db,
        listEntriesWithAuthorByMediaStatement(mediaId),
        entryWithAuthorRowSchema,
      );
      if (!entriesResult.ok) {
        return entriesResult;
      }

      const markersResult = await query(
        db,
        listMarkersByMediaIdStatement(mediaId),
        MARKERS_TABLE.rowSchema,
      );
      if (!markersResult.ok) {
        return markersResult;
      }

      const markersByEntry = new Map<string, Marker[]>();
      for (const markerRow of markersResult.value) {
        const marker = mapMarkerRowToEntity(markerRow);
        const list = markersByEntry.get(marker.entryId);
        if (list === undefined) {
          markersByEntry.set(marker.entryId, [marker]);
        } else {
          list.push(marker);
        }
      }

      return ok(
        entriesResult.value.map((row) =>
          mapEntryWithAuthorRowToEntity(row, markersByEntry.get(row.id) ?? []),
        ),
      );
    },

    getMaxMarkerNumber: async (mediaId) => {
      const result = await queryFirst(
        db,
        getMaxMarkerNumberStatement(mediaId),
        maxMarkerNumberRowSchema,
      );
      return mapResult(result, (row) => row?.max_number ?? 0);
    },

    insertWithMarkers: async ({ apartmentId, entry }) => {
      const result = await executeBatch(db, insertEntryWithMarkersStatements(apartmentId, entry));
      return mapResult(result, () => undefined);
    },

    retract: async ({ entryId, apartmentId, retractedAt }) => {
      const result = await executeBatch(
        db,
        retractEntryStatements(entryId, apartmentId, retractedAt),
      );
      return mapResult(result, () => undefined);
    },
  };
}
