import { createStatement, type SqlStatement } from '@stanmieszkania/d1';
import { z } from 'zod';
import { APARTMENTS_TABLE, apartmentRowSchema } from '../../apartments';
import { ENTRIES_TABLE, MARKERS_TABLE, entryRowSchema, markerRowSchema } from '../../entries';
import { MEDIA_TABLE, mediaRowSchema } from '../../media';
import { MEMBERSHIPS_TABLE } from '../../membership';
import { SYNC_ROLES } from '../domain/sync.constants';
import { CHANGE_LOG_TABLE } from './change-log.table';

const A = APARTMENTS_TABLE.columns;
const CL = CHANGE_LOG_TABLE.columns;
const E = ENTRIES_TABLE.columns;
const MK = MARKERS_TABLE.columns;
const MD = MEDIA_TABLE.columns;
const MB = MEMBERSHIPS_TABLE.columns;
const LIMIT_LOOKAHEAD = 1;

export const syncApartmentAccessRowSchema = z.object({
  id: z.string(),
  role: z.enum([SYNC_ROLES.OWNER, SYNC_ROLES.CONTRIBUTOR]).nullable(),
});

export const syncApartmentHydrationRowSchema = apartmentRowSchema.extend({
  latest_contributor_joined_at: z.string().nullable(),
});

export const myApartmentSyncRowSchema = apartmentRowSchema.extend({
  member_role: z.enum([SYNC_ROLES.OWNER, SYNC_ROLES.CONTRIBUTOR]),
  latest_contributor_joined_at: z.string().nullable(),
  head_seq: z.number().int(),
  confirmed_media_count: z.number().int(),
  latest_media_captured_at: z.string().nullable(),
});

export const syncMemberHydrationRowSchema = z.object({
  user_id: z.string(),
  display_name: z.string(),
  short_tag: z.string(),
  color: z.string(),
  role: z.enum([SYNC_ROLES.OWNER, SYNC_ROLES.CONTRIBUTOR]),
  joined_at: z.string(),
  left_at: z.string().nullable(),
});

export const syncMediaHydrationRowSchema = mediaRowSchema.extend({
  author_display_name: z.string(),
  author_short_tag: z.string(),
  author_color: z.string(),
  author_role: z.enum([SYNC_ROLES.OWNER, SYNC_ROLES.CONTRIBUTOR]).nullable(),
});

export const syncEntryHydrationRowSchema = entryRowSchema.extend({
  author_display_name: z.string(),
  author_short_tag: z.string(),
  author_color: z.string(),
  author_role: z.enum([SYNC_ROLES.OWNER, SYNC_ROLES.CONTRIBUTOR]).nullable(),
});

export type SyncApartmentHydrationRow = z.infer<typeof syncApartmentHydrationRowSchema>;
export type MyApartmentSyncRow = z.infer<typeof myApartmentSyncRowSchema>;
export type SyncMemberHydrationRow = z.infer<typeof syncMemberHydrationRowSchema>;
export type SyncMediaHydrationRow = z.infer<typeof syncMediaHydrationRowSchema>;
export type SyncEntryHydrationRow = z.infer<typeof syncEntryHydrationRowSchema>;
export { markerRowSchema };

function placeholders(count: number): string {
  return Array.from({ length: count }, () => '?').join(', ');
}

export function findSyncApartmentAccessStatement(
  apartmentId: string,
  userId: string,
): SqlStatement {
  return createStatement(
    `SELECT a.${A.id}, (SELECT mb.${MB.role} FROM ${MEMBERSHIPS_TABLE.name} mb WHERE mb.${MB.apartmentId} = a.${A.id} AND mb.${MB.userId} = ? AND mb.${MB.leftAt} IS NULL LIMIT 1) AS role FROM ${APARTMENTS_TABLE.name} a WHERE a.${A.id} = ? AND a.${A.deletedAt} IS NULL LIMIT 1`,
    [userId, apartmentId],
  );
}

export function listChangeLogAfterStatement(
  apartmentId: string,
  afterSeq: number,
  limit: number,
): SqlStatement {
  return createStatement(
    `SELECT ${CHANGE_LOG_TABLE.columnList()} FROM ${CHANGE_LOG_TABLE.name} WHERE ${CL.apartmentId} = ? AND ${CL.seq} > ? ORDER BY ${CL.seq} ASC LIMIT ?`,
    [apartmentId, afterSeq, limit + LIMIT_LOOKAHEAD],
  );
}

export function findApartmentForHydrationStatement(apartmentId: string): SqlStatement {
  return createStatement(
    `SELECT ${APARTMENTS_TABLE.columnList('a')}, (SELECT MAX(mc.${MB.joinedAt}) FROM ${MEMBERSHIPS_TABLE.name} mc WHERE mc.${MB.apartmentId} = a.${A.id} AND mc.${MB.role} = ? AND mc.${MB.leftAt} IS NULL) AS latest_contributor_joined_at FROM ${APARTMENTS_TABLE.name} a WHERE a.${A.id} = ? AND a.${A.deletedAt} IS NULL LIMIT 1`,
    [SYNC_ROLES.CONTRIBUTOR, apartmentId],
  );
}

export function listMembersForHydrationStatement(
  apartmentId: string,
  userIds: readonly string[],
): SqlStatement {
  return createStatement(
    `SELECT mb.${MB.userId}, u.display_name, u.short_tag, u.color, mb.${MB.role}, mb.${MB.joinedAt}, mb.${MB.leftAt} FROM ${MEMBERSHIPS_TABLE.name} mb INNER JOIN users u ON u.id = mb.${MB.userId} WHERE mb.${MB.apartmentId} = ? AND mb.${MB.userId} IN (${placeholders(userIds.length)})`,
    [apartmentId, ...userIds],
  );
}

export function listMediaForHydrationStatement(
  apartmentId: string,
  callerUserId: string,
  mediaIds: readonly string[],
): SqlStatement {
  return createStatement(
    `SELECT ${MEDIA_TABLE.columnList('m')}, u.display_name AS author_display_name, u.short_tag AS author_short_tag, u.color AS author_color, mb.${MB.role} AS author_role FROM ${MEDIA_TABLE.name} m INNER JOIN users u ON u.id = m.${MD.authorId} LEFT JOIN ${MEMBERSHIPS_TABLE.name} mb ON mb.${MB.apartmentId} = m.${MD.apartmentId} AND mb.${MB.userId} = m.${MD.authorId} WHERE m.${MD.apartmentId} = ? AND (m.${MD.uploadStatus} = 'confirmed' OR m.${MD.authorId} = ?) AND m.${MD.id} IN (${placeholders(mediaIds.length)})`,
    [apartmentId, callerUserId, ...mediaIds],
  );
}

export function listEntriesForHydrationStatement(
  apartmentId: string,
  entryIds: readonly string[],
): SqlStatement {
  return createStatement(
    `SELECT ${ENTRIES_TABLE.columnList('e')}, u.display_name AS author_display_name, u.short_tag AS author_short_tag, u.color AS author_color, mb.${MB.role} AS author_role FROM ${ENTRIES_TABLE.name} e INNER JOIN ${MEDIA_TABLE.name} m ON m.${MD.id} = e.${E.mediaId} INNER JOIN users u ON u.id = e.${E.authorId} LEFT JOIN ${MEMBERSHIPS_TABLE.name} mb ON mb.${MB.apartmentId} = m.${MD.apartmentId} AND mb.${MB.userId} = e.${E.authorId} WHERE m.${MD.apartmentId} = ? AND e.${E.id} IN (${placeholders(entryIds.length)})`,
    [apartmentId, ...entryIds],
  );
}

export function listMarkersForHydrationStatement(entryIds: readonly string[]): SqlStatement {
  return createStatement(
    `SELECT ${MARKERS_TABLE.columnList()} FROM ${MARKERS_TABLE.name} WHERE ${MK.entryId} IN (${placeholders(entryIds.length)}) ORDER BY ${MK.number} ASC`,
    [...entryIds],
  );
}

export function listMyApartmentsSyncStatement(userId: string): SqlStatement {
  return createStatement(
    `SELECT ${APARTMENTS_TABLE.columnList('a')}, m.${MB.role} AS member_role, (SELECT MAX(mc.${MB.joinedAt}) FROM ${MEMBERSHIPS_TABLE.name} mc WHERE mc.${MB.apartmentId} = a.${A.id} AND mc.${MB.role} = ? AND mc.${MB.leftAt} IS NULL) AS latest_contributor_joined_at, COALESCE((SELECT MAX(cl.${CL.seq}) FROM ${CHANGE_LOG_TABLE.name} cl WHERE cl.${CL.apartmentId} = a.${A.id}), 0) AS head_seq, (SELECT COUNT(*) FROM ${MEDIA_TABLE.name} md WHERE md.${MD.apartmentId} = a.${A.id} AND md.${MD.uploadStatus} = 'confirmed' AND md.${MD.deletedAt} IS NULL) AS confirmed_media_count, (SELECT MAX(md.${MD.capturedAt}) FROM ${MEDIA_TABLE.name} md WHERE md.${MD.apartmentId} = a.${A.id} AND md.${MD.uploadStatus} = 'confirmed' AND md.${MD.deletedAt} IS NULL) AS latest_media_captured_at FROM ${APARTMENTS_TABLE.name} a INNER JOIN ${MEMBERSHIPS_TABLE.name} m ON m.${MB.apartmentId} = a.${A.id} WHERE m.${MB.userId} = ? AND m.${MB.leftAt} IS NULL AND a.${A.deletedAt} IS NULL ORDER BY a.${A.createdAt} DESC, a.${A.id} DESC`,
    [SYNC_ROLES.CONTRIBUTOR, userId],
  );
}
