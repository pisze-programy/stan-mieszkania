import { createStatement, type SqlStatement } from '@stanmieszkania/d1';
import { DELETED_USER_DISPLAY_NAME } from '../domain/identity.constants';
import { USERS_TABLE, type UserRow } from './users.table';

const C = USERS_TABLE.columns;

export function findUserByIdStatement(id: string): SqlStatement {
  return createStatement(
    `SELECT ${USERS_TABLE.columnList()} FROM ${USERS_TABLE.name} WHERE ${C.id} = ? LIMIT 1`,
    [id],
  );
}

export function findUserByFirebaseUidStatement(firebaseUid: string): SqlStatement {
  return createStatement(
    `SELECT ${USERS_TABLE.columnList()} FROM ${USERS_TABLE.name} WHERE ${C.firebaseUid} = ? LIMIT 1`,
    [firebaseUid],
  );
}

export function insertUserStatement(row: UserRow): SqlStatement {
  return createStatement(
    `INSERT INTO ${USERS_TABLE.name} (${USERS_TABLE.columnList()}) VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      row.id,
      row.firebase_uid,
      row.display_name,
      row.short_tag,
      row.color,
      row.created_at,
      row.deleted_at,
    ],
  );
}

export function updateUserDisplayNameStatement(id: string, displayName: string): SqlStatement {
  return createStatement(
    `UPDATE ${USERS_TABLE.name} SET ${C.displayName} = ? WHERE ${C.id} = ? AND ${C.deletedAt} IS NULL`,
    [displayName, id],
  );
}

export function anonymizeUserStatement(id: string, deletedAt: string): SqlStatement {
  return createStatement(
    `UPDATE ${USERS_TABLE.name} SET ${C.firebaseUid} = NULL, ${C.displayName} = ?, ${C.deletedAt} = ? WHERE ${C.id} = ? AND ${C.deletedAt} IS NULL`,
    [DELETED_USER_DISPLAY_NAME, deletedAt, id],
  );
}
