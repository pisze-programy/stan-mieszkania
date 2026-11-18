import { createStatement, type SqlStatement } from '@stanmieszkania/d1';
import {
  APARTMENT_ROLES,
  CHANGE_LOG_ENTITY_TYPES,
  CHANGE_LOG_OPS,
} from '../domain/apartments.constants';
import { APARTMENT_CHANGES_TABLE, type ApartmentChangeRow } from './apartment-changes.table';
import { APARTMENTS_TABLE, type ApartmentRow } from './apartments.table';

const A = APARTMENTS_TABLE.columns;

export function insertApartmentStatement(row: ApartmentRow): SqlStatement {
  return createStatement(
    `INSERT INTO ${APARTMENTS_TABLE.name} (${APARTMENTS_TABLE.columnList()}) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      row.id,
      row.owner_id,
      row.name,
      row.street,
      row.city,
      row.invite_code,
      row.invite_code_rotated_at,
      row.cloud_media_count,
      row.orphan_delete_after,
      row.created_at,
      row.updated_at,
      row.deleted_at,
    ],
  );
}

export function insertOwnerMembershipStatement(
  apartmentId: string,
  userId: string,
  joinedAt: string,
): SqlStatement {
  return createStatement(
    'INSERT INTO memberships (apartment_id, user_id, role, joined_at, left_at) VALUES (?, ?, ?, ?, NULL)',
    [apartmentId, userId, APARTMENT_ROLES.OWNER, joinedAt],
  );
}

export function updateApartmentMetadataStatement(row: ApartmentRow): SqlStatement {
  return createStatement(
    `UPDATE ${APARTMENTS_TABLE.name} SET ${A.name} = ?, ${A.street} = ?, ${A.city} = ?, ${A.updatedAt} = ? WHERE ${A.id} = ? AND ${A.deletedAt} IS NULL`,
    [row.name, row.street, row.city, row.updated_at, row.id],
  );
}

export function insertApartmentChangeStatement(row: ApartmentChangeRow): SqlStatement {
  return createStatement(
    `INSERT INTO ${APARTMENT_CHANGES_TABLE.name} (${APARTMENT_CHANGES_TABLE.columnList()}) VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      row.id,
      row.apartment_id,
      row.author_id,
      row.field,
      row.old_value,
      row.new_value,
      row.created_at,
    ],
  );
}

export function updateInviteCodeStatement(
  apartmentId: string,
  inviteCode: string,
  rotatedAt: string,
): SqlStatement {
  return createStatement(
    `UPDATE ${APARTMENTS_TABLE.name} SET ${A.inviteCode} = ?, ${A.inviteCodeRotatedAt} = ?, ${A.updatedAt} = ? WHERE ${A.id} = ? AND ${A.deletedAt} IS NULL`,
    [inviteCode, rotatedAt, rotatedAt, apartmentId],
  );
}

export function updateApartmentOwnerStatement(
  apartmentId: string,
  newOwnerId: string,
  updatedAt: string,
): SqlStatement {
  return createStatement(
    `UPDATE ${APARTMENTS_TABLE.name} SET ${A.ownerId} = ?, ${A.updatedAt} = ? WHERE ${A.id} = ? AND ${A.deletedAt} IS NULL`,
    [newOwnerId, updatedAt, apartmentId],
  );
}

export function markMembershipLeftStatement(
  apartmentId: string,
  userId: string,
  leftAt: string,
): SqlStatement {
  return createStatement(
    'UPDATE memberships SET left_at = ? WHERE apartment_id = ? AND user_id = ? AND left_at IS NULL',
    [leftAt, apartmentId, userId],
  );
}

export function promoteMembershipToOwnerStatement(
  apartmentId: string,
  userId: string,
): SqlStatement {
  return createStatement(
    'UPDATE memberships SET role = ? WHERE apartment_id = ? AND user_id = ? AND left_at IS NULL',
    [APARTMENT_ROLES.OWNER, apartmentId, userId],
  );
}

export function insertChangeLogStatement(
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

export function transferOwnershipAndLeaveStatements(
  apartmentId: string,
  previousOwnerId: string,
  newOwnerId: string,
  leftAt: string,
): readonly SqlStatement[] {
  return [
    updateApartmentOwnerStatement(apartmentId, newOwnerId, leftAt),
    markMembershipLeftStatement(apartmentId, previousOwnerId, leftAt),
    promoteMembershipToOwnerStatement(apartmentId, newOwnerId),
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

export function leaveAsContributorStatements(
  apartmentId: string,
  userId: string,
  leftAt: string,
): readonly SqlStatement[] {
  return [
    markMembershipLeftStatement(apartmentId, userId, leftAt),
    insertChangeLogStatement(
      apartmentId,
      CHANGE_LOG_ENTITY_TYPES.MEMBERSHIP,
      userId,
      CHANGE_LOG_OPS.LEFT,
      leftAt,
    ),
  ];
}

// 0001_init enforces ON DELETE RESTRICT on all apartment children; delete in reverse FK order.
export function hardDeleteApartmentStatements(apartmentId: string): readonly SqlStatement[] {
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
    createStatement('DELETE FROM memberships WHERE apartment_id = ?', [apartmentId]),
    createStatement('DELETE FROM change_log WHERE apartment_id = ?', [apartmentId]),
    createStatement(`DELETE FROM ${APARTMENTS_TABLE.name} WHERE ${A.id} = ?`, [apartmentId]),
  ];
}
