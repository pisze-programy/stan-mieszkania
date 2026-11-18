import type { User } from '../domain/user.entity';
import type { UserRow } from './users.table';

export function mapUserRowToEntity(row: UserRow): User {
  return {
    id: row.id,
    firebaseUid: row.firebase_uid,
    displayName: row.display_name,
    shortTag: row.short_tag,
    color: row.color,
    createdAt: row.created_at,
    deletedAt: row.deleted_at,
  };
}

export function mapUserEntityToRow(user: User): UserRow {
  return {
    id: user.id,
    firebase_uid: user.firebaseUid,
    display_name: user.displayName,
    short_tag: user.shortTag,
    color: user.color,
    created_at: user.createdAt,
    deleted_at: user.deletedAt,
  };
}
