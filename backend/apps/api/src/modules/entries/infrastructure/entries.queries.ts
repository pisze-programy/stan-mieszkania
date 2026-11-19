import { createStatement, type SqlStatement } from '@stanmieszkania/d1';
import { z } from 'zod';
import { APARTMENTS_TABLE } from '../../apartments';
import { MEDIA_TABLE } from '../../media';
import {
  ENTRY_CHANGE_LOG_ENTITY_TYPE,
  ENTRY_CHANGE_LOG_OPS,
  REDACTED_ENTRY_TEXT,
} from '../domain/entries.constants';
import type { Entry } from '../domain/entry.entity';
import { ENTRIES_TABLE, entryRowSchema } from './entries.table';
import { mapEntryEntityToRow, mapMarkerEntityToRow } from './entry-row.mapper';
import { MARKERS_TABLE } from './markers.table';

const A = APARTMENTS_TABLE.columns;
const M = MEDIA_TABLE.columns;
const E = ENTRIES_TABLE.columns;
const K = MARKERS_TABLE.columns;

export const apartmentMembershipRowSchema = z.object({
  apartment_id: z.string(),
  is_active_member: z.number().int(),
});

export const targetMediaAccessRowSchema = z.object({
  media_id: z.string(),
  apartment_id: z.string(),
  author_id: z.string(),
  upload_status: z.enum(['pending', 'confirmed']),
  deleted_at: z.string().nullable(),
  is_active_member: z.number().int(),
});

export const entryWithAuthorRowSchema = entryRowSchema.extend({
  author_display_name: z.string(),
  author_short_tag: z.string(),
  author_color: z.string(),
  author_role: z.enum(['owner', 'contributor']).nullable(),
});

export const maxMarkerNumberRowSchema = z.object({
  max_number: z.number().int(),
});

export function findApartmentMembershipStatement(
  apartmentId: string,
  userId: string,
): SqlStatement {
  return createStatement(
    `SELECT a.${A.id} AS apartment_id, EXISTS (SELECT 1 FROM memberships mb WHERE mb.apartment_id = a.${A.id} AND mb.user_id = ? AND mb.left_at IS NULL) AS is_active_member FROM ${APARTMENTS_TABLE.name} a WHERE a.${A.id} = ? AND a.${A.deletedAt} IS NULL LIMIT 1`,
    [userId, apartmentId],
  );
}

export function findTargetMediaAccessStatement(mediaId: string, userId: string): SqlStatement {
  return createStatement(
    `SELECT m.${M.id} AS media_id, m.${M.apartmentId} AS apartment_id, m.${M.authorId} AS author_id, m.${M.uploadStatus} AS upload_status, m.${M.deletedAt} AS deleted_at, EXISTS (SELECT 1 FROM memberships mb WHERE mb.apartment_id = m.${M.apartmentId} AND mb.user_id = ? AND mb.left_at IS NULL) AS is_active_member FROM ${MEDIA_TABLE.name} m INNER JOIN ${APARTMENTS_TABLE.name} a ON a.${A.id} = m.${M.apartmentId} WHERE m.${M.id} = ? AND a.${A.deletedAt} IS NULL LIMIT 1`,
    [userId, mediaId],
  );
}

export function findEntryByIdStatement(entryId: string): SqlStatement {
  return createStatement(
    `SELECT ${ENTRIES_TABLE.columnList()} FROM ${ENTRIES_TABLE.name} WHERE ${E.id} = ? LIMIT 1`,
    [entryId],
  );
}

export function findEntryWithAuthorByIdStatement(entryId: string): SqlStatement {
  return createStatement(
    `SELECT ${ENTRIES_TABLE.columnList('e')}, u.display_name AS author_display_name, u.short_tag AS author_short_tag, u.color AS author_color, mb.role AS author_role FROM ${ENTRIES_TABLE.name} e INNER JOIN ${MEDIA_TABLE.name} m ON m.${M.id} = e.${E.mediaId} INNER JOIN users u ON u.id = e.${E.authorId} LEFT JOIN memberships mb ON mb.apartment_id = m.${M.apartmentId} AND mb.user_id = e.${E.authorId} WHERE e.${E.id} = ? LIMIT 1`,
    [entryId],
  );
}

export function listEntriesWithAuthorByMediaStatement(mediaId: string): SqlStatement {
  return createStatement(
    `SELECT ${ENTRIES_TABLE.columnList('e')}, u.display_name AS author_display_name, u.short_tag AS author_short_tag, u.color AS author_color, mb.role AS author_role FROM ${ENTRIES_TABLE.name} e INNER JOIN ${MEDIA_TABLE.name} m ON m.${M.id} = e.${E.mediaId} INNER JOIN users u ON u.id = e.${E.authorId} LEFT JOIN memberships mb ON mb.apartment_id = m.${M.apartmentId} AND mb.user_id = e.${E.authorId} WHERE e.${E.mediaId} = ? ORDER BY e.${E.createdAt} ASC, e.${E.id} ASC`,
    [mediaId],
  );
}

export function listMarkersByEntryIdStatement(entryId: string): SqlStatement {
  return createStatement(
    `SELECT ${MARKERS_TABLE.columnList()} FROM ${MARKERS_TABLE.name} WHERE ${K.entryId} = ? ORDER BY ${K.number} ASC, ${K.id} ASC`,
    [entryId],
  );
}

export function listMarkersByMediaIdStatement(mediaId: string): SqlStatement {
  return createStatement(
    `SELECT ${MARKERS_TABLE.columnList()} FROM ${MARKERS_TABLE.name} WHERE ${K.mediaId} = ? ORDER BY ${K.number} ASC, ${K.id} ASC`,
    [mediaId],
  );
}

export function getMaxMarkerNumberStatement(mediaId: string): SqlStatement {
  return createStatement(
    `SELECT COALESCE(MAX(${K.number}), 0) AS max_number FROM ${MARKERS_TABLE.name} WHERE ${K.mediaId} = ?`,
    [mediaId],
  );
}

export function insertEntryWithMarkersStatements(
  apartmentId: string,
  entry: Entry,
): readonly SqlStatement[] {
  const entryRow = mapEntryEntityToRow(entry);
  const statements: SqlStatement[] = [
    createStatement(
      `INSERT INTO ${ENTRIES_TABLE.name} (${ENTRIES_TABLE.columnList()}) VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        entryRow.id,
        entryRow.media_id,
        entryRow.author_id,
        entryRow.text,
        entryRow.created_at,
        entryRow.server_received_at,
        entryRow.retracted_at,
      ],
    ),
  ];

  for (const marker of entry.markers) {
    const markerRow = mapMarkerEntityToRow(marker);
    statements.push(
      createStatement(
        `INSERT INTO ${MARKERS_TABLE.name} (${MARKERS_TABLE.columnList()}) VALUES (?, ?, ?, ?, ?, ?)`,
        [
          markerRow.id,
          markerRow.entry_id,
          markerRow.media_id,
          markerRow.number,
          markerRow.x,
          markerRow.y,
        ],
      ),
    );
  }

  statements.push(
    createStatement(
      'INSERT INTO change_log (apartment_id, entity_type, entity_id, op, created_at) VALUES (?, ?, ?, ?, ?)',
      [
        apartmentId,
        ENTRY_CHANGE_LOG_ENTITY_TYPE,
        entry.id,
        ENTRY_CHANGE_LOG_OPS.CREATED,
        entry.serverReceivedAt,
      ],
    ),
  );

  return statements;
}

export function retractEntryStatements(
  entryId: string,
  apartmentId: string,
  retractedAt: string,
): readonly SqlStatement[] {
  return [
    createStatement(
      `UPDATE ${ENTRIES_TABLE.name} SET ${E.text} = ?, ${E.retractedAt} = ? WHERE ${E.id} = ? AND ${E.retractedAt} IS NULL`,
      [REDACTED_ENTRY_TEXT, retractedAt, entryId],
    ),
    createStatement(
      'INSERT INTO change_log (apartment_id, entity_type, entity_id, op, created_at) VALUES (?, ?, ?, ?, ?)',
      [
        apartmentId,
        ENTRY_CHANGE_LOG_ENTITY_TYPE,
        entryId,
        ENTRY_CHANGE_LOG_OPS.RETRACTED,
        retractedAt,
      ],
    ),
  ];
}
