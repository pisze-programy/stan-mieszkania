import {
  executeBatch,
  query,
  queryFirst,
  type D1Client,
  type D1PreparedStatementLike,
  type D1Queryable,
} from '@stanmieszkania/d1';
import { err, mapResult, ok } from '@stanmieszkania/shared';
import { quotaExceededError } from '../domain/media.errors';
import type { MediaRepository } from '../domain/media.repository';
import {
  decodeMediaCursor,
  encodeMediaCursor,
  mapMediaEntityToRow,
  mapMediaRowToEntity,
  mapMediaWithAuthorRow,
  type DecodedMediaCursor,
} from './media-row.mapper';
import {
  apartmentAccessRowSchema,
  findApartmentAccessStatement,
  findMediaByIdStatement,
  findMediaWithAuthorByIdStatement,
  listApartmentMediaStatement,
  markMediaConfirmedStatements,
  mediaWithAuthorRowSchema,
  reservePendingMediaStatements,
  softDeleteMediaStatements,
} from './media.queries';
import { MEDIA_TABLE } from './media.table';

const ACTIVE_MEMBER_FLAG = 1;

export function createD1MediaRepository<TStatement extends D1PreparedStatementLike<TStatement>>(
  db: D1Client<TStatement> & D1Queryable,
): MediaRepository {
  return {
    findApartmentAccess: async (apartmentId, userId) => {
      const result = await queryFirst(
        db,
        findApartmentAccessStatement(apartmentId, userId),
        apartmentAccessRowSchema,
      );
      return mapResult(result, (row) =>
        row === null
          ? null
          : {
              apartmentId: row.id,
              cloudMediaCount: row.cloud_media_count,
              isActiveMember: row.is_active_member === ACTIVE_MEMBER_FLAG,
            },
      );
    },
    findById: async (mediaId) => {
      const result = await queryFirst(db, findMediaByIdStatement(mediaId), MEDIA_TABLE.rowSchema);
      return mapResult(result, (row) => (row === null ? null : mapMediaRowToEntity(row)));
    },
    findByIdWithAuthor: async (mediaId) => {
      const result = await queryFirst(
        db,
        findMediaWithAuthorByIdStatement(mediaId),
        mediaWithAuthorRowSchema,
      );
      return mapResult(result, (row) => (row === null ? null : mapMediaWithAuthorRow(row)));
    },
    listByApartment: async ({ apartmentId, after, limit }) => {
      let decoded: DecodedMediaCursor | undefined;
      if (after !== undefined) {
        const parsed = decodeMediaCursor(after);
        if (!parsed.ok) {
          return parsed;
        }
        decoded = parsed.value;
      }

      const result = await query(
        db,
        listApartmentMediaStatement(apartmentId, limit, decoded),
        mediaWithAuthorRowSchema,
      );
      return mapResult(result, (rows) => {
        const hasMore = rows.length > limit;
        const pageRows = hasMore ? rows.slice(0, limit) : rows;
        const items = pageRows.map(mapMediaWithAuthorRow);
        const lastItem = items[items.length - 1];
        return {
          items,
          hasMore,
          nextCursor: hasMore && lastItem !== undefined ? encodeMediaCursor(lastItem.media) : null,
        };
      });
    },
    reservePendingSlot: async ({ media, quota, createdAt }) => {
      const row = mapMediaEntityToRow(media);
      const result = await executeBatch(db, reservePendingMediaStatements(row, quota, createdAt));
      if (!result.ok) {
        return result;
      }
      const insertChanges = result.value[0]?.meta.changes;
      if (typeof insertChanges === 'number' && insertChanges === 0) {
        return err(quotaExceededError(quota, quota));
      }
      return ok(undefined);
    },
    markUploaded: async ({ mediaId, apartmentId, serverReceivedAt }) => {
      const result = await executeBatch(
        db,
        markMediaConfirmedStatements(mediaId, apartmentId, serverReceivedAt),
      );
      return mapResult(result, () => undefined);
    },
    softDelete: async ({ mediaId, apartmentId, deletedBy, deletedAt }) => {
      const result = await executeBatch(
        db,
        softDeleteMediaStatements(mediaId, apartmentId, deletedBy, deletedAt),
      );
      return mapResult(result, () => undefined);
    },
  };
}
