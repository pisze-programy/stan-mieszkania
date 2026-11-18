import { createStatement, type SqlStatement } from '@stanmieszkania/d1';
import { z } from 'zod';
import {
  APARTMENT_CHANGES_TABLE,
  APARTMENT_ROLES,
  APARTMENTS_TABLE,
  CHANGE_LOG_ENTITY_TYPES,
  CHANGE_LOG_OPS,
} from '../../apartments';
import { USERS_TABLE } from '../../identity';
import { MEMBERSHIPS_TABLE } from '../../membership';

const A = APARTMENTS_TABLE.columns;
const M = MEMBERSHIPS_TABLE.columns;
const U = USERS_TABLE.columns;

export const userApartmentMembershipRowSchema = z.object({
  apartment_id: z.string(),
  role: z.enum([APARTMENT_ROLES.OWNER, APARTMENT_ROLES.CONTRIBUTOR]),
  left_at: z.string().nullable(),
  has_shared_history: z.number().int(),
});

export const activeContributorRowSchema = z.object({
  user_id: z.string(),
  joined_at: z.string(),
});

export const mediaR2KeyRowSchema = z.object({
  r2_key: z.string(),
});

function insertChangeLogStatement(
  apartmentId: string,
  entityType: string,
  entityId: string,
  op: string,
  createdAt: string,
): SqlStatement {
  return createStatement(
    'INSERT INTO change_log (apartment_id, entity_type, entity_id, op, created_at) VALUES (?, ?, ?, ?, ?)',
    [apartmentId, entityType, entityId, op, createdAt],
  );
}

export function listUserApartmentMembershipsStatement(userId: string): SqlStatement {
  return createStatement(
    `SELECT m.${M.apartmentId} AS apartment_id, m.${M.role} AS role, m.${M.leftAt} AS left_at, ` +
      `CASE WHEN EXISTS (SELECT 1 FROM ${MEMBERSHIPS_TABLE.name} m2 WHERE m2.${M.apartmentId} = a.${A.id} AND m2.${M.userId} <> ?) ` +
      `OR EXISTS (SELECT 1 FROM media med WHERE med.apartment_id = a.${A.id} AND med.author_id <> ?) ` +
      `OR EXISTS (SELECT 1 FROM entries e INNER JOIN media med ON med.id = e.media_id WHERE med.apartment_id = a.${A.id} AND e.author_id <> ?) ` +
      `THEN 1 ELSE 0 END AS has_shared_history ` +
      `FROM ${MEMBERSHIPS_TABLE.name} m ` +
      `INNER JOIN ${APARTMENTS_TABLE.name} a ON a.${A.id} = m.${M.apartmentId} ` +
      `WHERE m.${M.userId} = ? AND a.${A.deletedAt} IS NULL ` +
      `ORDER BY a.${A.createdAt} ASC, a.${A.id} ASC`,
    [userId, userId, userId, userId],
  );
}

export function listActiveContributorsStatement(apartmentId: string): SqlStatement {
  return createStatement(
    `SELECT ${M.userId} AS user_id, ${M.joinedAt} AS joined_at FROM ${MEMBERSHIPS_TABLE.name} ` +
      `WHERE ${M.apartmentId} = ? AND ${M.role} = ? AND ${M.leftAt} IS NULL ` +
      `ORDER BY ${M.joinedAt} ASC, ${M.userId} ASC`,
    [apartmentId, APARTMENT_ROLES.CONTRIBUTOR],
  );
}

export function listApartmentMediaR2KeysStatement(apartmentId: string): SqlStatement {
  return createStatement('SELECT r2_key FROM media WHERE apartment_id = ? ORDER BY id ASC', [
    apartmentId,
  ]);
}

// 0001_init enforces ON DELETE RESTRICT on all apartment children; delete in reverse FK order.
export function hardDeletePrivateApartmentStatements(apartmentId: string): readonly SqlStatement[] {
  return [
    createStatement(
      'DELETE FROM markers WHERE media_id IN (SELECT id FROM media WHERE apartment_id = ?)',
      [apartmentId],
    ),
    createStatement(
      'DELETE FROM entries WHERE media_id IN (SELECT id FROM media WHERE apartment_id = ?)',
      [apartmentId],
    ),
    createStatement('DELETE FROM media WHERE apartment_id = ?', [apartmentId]),
    createStatement(`DELETE FROM ${APARTMENT_CHANGES_TABLE.name} WHERE apartment_id = ?`, [
      apartmentId,
    ]),
    createStatement(`DELETE FROM ${MEMBERSHIPS_TABLE.name} WHERE ${M.apartmentId} = ?`, [
      apartmentId,
    ]),
    createStatement('DELETE FROM change_log WHERE apartment_id = ?', [apartmentId]),
    createStatement(`DELETE FROM ${APARTMENTS_TABLE.name} WHERE ${A.id} = ?`, [apartmentId]),
  ];
}

export function transferOwnershipAndLeaveStatements(
  apartmentId: string,
  previousOwnerId: string,
  newOwnerId: string,
  leftAt: string,
): readonly SqlStatement[] {
  return [
    createStatement(
      `UPDATE ${APARTMENTS_TABLE.name} SET ${A.ownerId} = ?, ${A.updatedAt} = ? WHERE ${A.id} = ? AND ${A.deletedAt} IS NULL`,
      [newOwnerId, leftAt, apartmentId],
    ),
    createStatement(
      `UPDATE ${MEMBERSHIPS_TABLE.name} SET ${M.role} = ? WHERE ${M.apartmentId} = ? AND ${M.userId} = ? AND ${M.leftAt} IS NULL`,
      [APARTMENT_ROLES.OWNER, apartmentId, newOwnerId],
    ),
    createStatement(
      `UPDATE ${MEMBERSHIPS_TABLE.name} SET ${M.leftAt} = ? WHERE ${M.apartmentId} = ? AND ${M.userId} = ? AND ${M.leftAt} IS NULL`,
      [leftAt, apartmentId, previousOwnerId],
    ),
    insertChangeLogStatement(
      apartmentId,
      CHANGE_LOG_ENTITY_TYPES.APARTMENT,
      apartmentId,
      CHANGE_LOG_OPS.OWNERSHIP_TRANSFERRED,
      leftAt,
    ),
    insertChangeLogStatement(
      apartmentId,
      CHANGE_LOG_ENTITY_TYPES.MEMBERSHIP,
      previousOwnerId,
      CHANGE_LOG_OPS.LEFT,
      leftAt,
    ),
    insertChangeLogStatement(
      apartmentId,
      CHANGE_LOG_ENTITY_TYPES.MEMBERSHIP,
      newOwnerId,
      CHANGE_LOG_OPS.PROMOTED,
      leftAt,
    ),
  ];
}

export function scheduleOrphanDeleteAndLeaveStatements(
  apartmentId: string,
  ownerId: string,
  orphanDeleteAfter: string,
  leftAt: string,
): readonly SqlStatement[] {
  return [
    createStatement(
      `UPDATE ${APARTMENTS_TABLE.name} SET ${A.orphanDeleteAfter} = ?, ${A.updatedAt} = ? WHERE ${A.id} = ? AND ${A.deletedAt} IS NULL`,
      [orphanDeleteAfter, leftAt, apartmentId],
    ),
    createStatement(
      `UPDATE ${MEMBERSHIPS_TABLE.name} SET ${M.leftAt} = ? WHERE ${M.apartmentId} = ? AND ${M.userId} = ? AND ${M.leftAt} IS NULL`,
      [leftAt, apartmentId, ownerId],
    ),
    insertChangeLogStatement(
      apartmentId,
      CHANGE_LOG_ENTITY_TYPES.APARTMENT,
      apartmentId,
      CHANGE_LOG_OPS.UPDATED,
      leftAt,
    ),
    insertChangeLogStatement(
      apartmentId,
      CHANGE_LOG_ENTITY_TYPES.MEMBERSHIP,
      ownerId,
      CHANGE_LOG_OPS.LEFT,
      leftAt,
    ),
  ];
}

export function leaveAsContributorStatements(
  apartmentId: string,
  userId: string,
  leftAt: string,
): readonly SqlStatement[] {
  return [
    createStatement(
      `UPDATE ${MEMBERSHIPS_TABLE.name} SET ${M.leftAt} = ? WHERE ${M.apartmentId} = ? AND ${M.userId} = ? AND ${M.leftAt} IS NULL`,
      [leftAt, apartmentId, userId],
    ),
    insertChangeLogStatement(
      apartmentId,
      CHANGE_LOG_ENTITY_TYPES.MEMBERSHIP,
      userId,
      CHANGE_LOG_OPS.LEFT,
      leftAt,
    ),
  ];
}

export function anonymizeUserPreservingUidStatement(
  userId: string,
  displayName: string,
  deletedAt: string,
): SqlStatement {
  return createStatement(
    `UPDATE ${USERS_TABLE.name} SET ${U.displayName} = ?, ${U.deletedAt} = ? WHERE ${U.id} = ? AND ${U.deletedAt} IS NULL`,
    [displayName, deletedAt, userId],
  );
}
