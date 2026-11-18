import { createStatement, type SqlStatement } from '@stanmieszkania/d1';
import { z } from 'zod';
import { APARTMENTS_TABLE } from '../../apartments';
import { MEDIA_CHANGE_LOG_ENTITY_TYPE, MEDIA_CHANGE_LOG_OPS } from '../domain/media.constants';
import type { DecodedMediaCursor } from './media-row.mapper';
import { MEDIA_TABLE, mediaRowSchema, type MediaRow } from './media.table';

const A = APARTMENTS_TABLE.columns;
const M = MEDIA_TABLE.columns;
const INITIAL_CHANGES_OFFSET = 1;

export const apartmentAccessRowSchema = z.object({
  id: z.string(),
  cloud_media_count: z.number().int(),
  is_active_member: z.number().int(),
});

export const mediaWithAuthorRowSchema = mediaRowSchema.extend({
  author_display_name: z.string(),
  author_short_tag: z.string(),
  author_color: z.string(),
  author_role: z.enum(['owner', 'contributor']).nullable(),
});

export function findApartmentAccessStatement(apartmentId: string, userId: string): SqlStatement {
  return createStatement(
    `SELECT a.${A.id}, a.${A.cloudMediaCount}, EXISTS (SELECT 1 FROM memberships mb WHERE mb.apartment_id = a.${A.id} AND mb.user_id = ? AND mb.left_at IS NULL) AS is_active_member FROM ${APARTMENTS_TABLE.name} a WHERE a.${A.id} = ? AND a.${A.deletedAt} IS NULL LIMIT 1`,
    [userId, apartmentId],
  );
}

export function findMediaByIdStatement(mediaId: string): SqlStatement {
  return createStatement(
    `SELECT ${MEDIA_TABLE.columnList()} FROM ${MEDIA_TABLE.name} WHERE ${M.id} = ? LIMIT 1`,
    [mediaId],
  );
}

export function findMediaWithAuthorByIdStatement(mediaId: string): SqlStatement {
  return createStatement(
    `SELECT ${MEDIA_TABLE.columnList('m')}, u.display_name AS author_display_name, u.short_tag AS author_short_tag, u.color AS author_color, mb.role AS author_role FROM ${MEDIA_TABLE.name} m INNER JOIN users u ON u.id = m.${M.authorId} LEFT JOIN memberships mb ON mb.apartment_id = m.${M.apartmentId} AND mb.user_id = m.${M.authorId} WHERE m.${M.id} = ? LIMIT 1`,
    [mediaId],
  );
}

export function listApartmentMediaStatement(
  apartmentId: string,
  limit: number,
  cursor?: DecodedMediaCursor,
): SqlStatement {
  const fetchLimit = limit + INITIAL_CHANGES_OFFSET;
  if (cursor === undefined) {
    return createStatement(
      `SELECT ${MEDIA_TABLE.columnList('m')}, u.display_name AS author_display_name, u.short_tag AS author_short_tag, u.color AS author_color, mb.role AS author_role FROM ${MEDIA_TABLE.name} m INNER JOIN users u ON u.id = m.${M.authorId} LEFT JOIN memberships mb ON mb.apartment_id = m.${M.apartmentId} AND mb.user_id = m.${M.authorId} WHERE m.${M.apartmentId} = ? ORDER BY m.${M.capturedAt} DESC, m.${M.id} DESC LIMIT ?`,
      [apartmentId, fetchLimit],
    );
  }
  return createStatement(
    `SELECT ${MEDIA_TABLE.columnList('m')}, u.display_name AS author_display_name, u.short_tag AS author_short_tag, u.color AS author_color, mb.role AS author_role FROM ${MEDIA_TABLE.name} m INNER JOIN users u ON u.id = m.${M.authorId} LEFT JOIN memberships mb ON mb.apartment_id = m.${M.apartmentId} AND mb.user_id = m.${M.authorId} WHERE m.${M.apartmentId} = ? AND (m.${M.capturedAt} < ? OR (m.${M.capturedAt} = ? AND m.${M.id} < ?)) ORDER BY m.${M.capturedAt} DESC, m.${M.id} DESC LIMIT ?`,
    [apartmentId, cursor.capturedAt, cursor.capturedAt, cursor.id, fetchLimit],
  );
}

export function reservePendingMediaStatements(
  row: MediaRow,
  quota: number,
  createdAt: string,
): readonly SqlStatement[] {
  return [
    createStatement(
      `INSERT INTO ${MEDIA_TABLE.name} (${MEDIA_TABLE.columnList()}) SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? FROM ${APARTMENTS_TABLE.name} WHERE ${A.id} = ? AND ${A.deletedAt} IS NULL AND ${A.cloudMediaCount} < ?`,
      [
        row.id,
        row.apartment_id,
        row.author_id,
        row.kind,
        row.source,
        row.upload_status,
        row.sha256,
        row.captured_at,
        row.captured_tz,
        row.captured_at_from_import,
        row.server_received_at,
        row.lat,
        row.lng,
        row.accuracy_m,
        row.location_source,
        row.width,
        row.height,
        row.bytes,
        row.r2_key,
        row.deleted_at,
        row.deleted_by,
        row.apartment_id,
        quota,
      ],
    ),
    createStatement(
      `UPDATE ${APARTMENTS_TABLE.name} SET ${A.cloudMediaCount} = ${A.cloudMediaCount} + 1, ${A.updatedAt} = ? WHERE ${A.id} = ? AND ${A.deletedAt} IS NULL AND EXISTS (SELECT 1 FROM ${MEDIA_TABLE.name} WHERE ${M.id} = ?)`,
      [createdAt, row.apartment_id, row.id],
    ),
    createStatement(
      `INSERT INTO change_log (apartment_id, entity_type, entity_id, op, created_at) SELECT ?, ?, ?, ?, ? WHERE EXISTS (SELECT 1 FROM ${MEDIA_TABLE.name} WHERE ${M.id} = ?)`,
      [
        row.apartment_id,
        MEDIA_CHANGE_LOG_ENTITY_TYPE,
        row.id,
        MEDIA_CHANGE_LOG_OPS.PENDING,
        createdAt,
        row.id,
      ],
    ),
  ];
}

export function markMediaConfirmedStatements(
  mediaId: string,
  apartmentId: string,
  serverReceivedAt: string,
): readonly SqlStatement[] {
  return [
    createStatement(
      `UPDATE ${MEDIA_TABLE.name} SET ${M.uploadStatus} = ?, ${M.serverReceivedAt} = ? WHERE ${M.id} = ? AND ${M.uploadStatus} = ? AND ${M.deletedAt} IS NULL`,
      ['confirmed', serverReceivedAt, mediaId, 'pending'],
    ),
    createStatement(
      'INSERT INTO change_log (apartment_id, entity_type, entity_id, op, created_at) VALUES (?, ?, ?, ?, ?)',
      [
        apartmentId,
        MEDIA_CHANGE_LOG_ENTITY_TYPE,
        mediaId,
        MEDIA_CHANGE_LOG_OPS.CONFIRMED,
        serverReceivedAt,
      ],
    ),
  ];
}

export function softDeleteMediaStatements(
  mediaId: string,
  apartmentId: string,
  deletedBy: string,
  deletedAt: string,
): readonly SqlStatement[] {
  // Decision S2-5: Soft-delete sets tombstone without decrementing apartments.cloud_media_count.
  return [
    createStatement(
      `UPDATE ${MEDIA_TABLE.name} SET ${M.deletedAt} = ?, ${M.deletedBy} = ? WHERE ${M.id} = ? AND ${M.authorId} = ? AND ${M.deletedAt} IS NULL`,
      [deletedAt, deletedBy, mediaId, deletedBy],
    ),
    createStatement(
      'INSERT INTO change_log (apartment_id, entity_type, entity_id, op, created_at) VALUES (?, ?, ?, ?, ?)',
      [
        apartmentId,
        MEDIA_CHANGE_LOG_ENTITY_TYPE,
        mediaId,
        MEDIA_CHANGE_LOG_OPS.SOFT_DELETED,
        deletedAt,
      ],
    ),
  ];
}
