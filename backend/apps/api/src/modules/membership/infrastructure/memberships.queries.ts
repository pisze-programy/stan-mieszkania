import { createStatement, type SqlStatement } from '@stanmieszkania/d1';
import { z } from 'zod';
import { APARTMENTS_TABLE } from '../../apartments';
import {
  MEMBERSHIP_CHANGE_LOG_ENTITY_TYPE,
  MEMBERSHIP_ROLES,
} from '../domain/membership.constants';
import { MEMBERSHIPS_TABLE } from './memberships.table';

const A = APARTMENTS_TABLE.columns;
const M = MEMBERSHIPS_TABLE.columns;

export const apartmentIdOnlyRowSchema = z.object({
  id: z.string(),
});

export const latestJoinedAtRowSchema = z.object({
  latest_joined_at: z.string().nullable(),
});

export const memberViewRowSchema = z.object({
  user_id: z.string(),
  display_name: z.string(),
  short_tag: z.string(),
  color: z.string(),
  role: z.enum([MEMBERSHIP_ROLES.OWNER, MEMBERSHIP_ROLES.CONTRIBUTOR]),
  joined_at: z.string(),
  left_at: z.string().nullable(),
});

export type MemberViewRow = z.infer<typeof memberViewRowSchema>;

export function findActiveApartmentIdStatement(apartmentId: string): SqlStatement {
  return createStatement(
    `SELECT ${A.id} FROM ${APARTMENTS_TABLE.name} WHERE ${A.id} = ? AND ${A.deletedAt} IS NULL LIMIT 1`,
    [apartmentId],
  );
}

export function findApartmentByInviteCodeStatement(inviteCode: string): SqlStatement {
  return createStatement(
    `SELECT ${APARTMENTS_TABLE.columnList()} FROM ${APARTMENTS_TABLE.name} WHERE ${A.inviteCode} = ? AND ${A.deletedAt} IS NULL LIMIT 1`,
    [inviteCode],
  );
}

export function findMembershipStatement(apartmentId: string, userId: string): SqlStatement {
  return createStatement(
    `SELECT ${MEMBERSHIPS_TABLE.columnList()} FROM ${MEMBERSHIPS_TABLE.name} WHERE ${M.apartmentId} = ? AND ${M.userId} = ? LIMIT 1`,
    [apartmentId, userId],
  );
}

export function getLatestContributorJoinedAtStatement(apartmentId: string): SqlStatement {
  return createStatement(
    `SELECT MAX(${M.joinedAt}) AS latest_joined_at FROM ${MEMBERSHIPS_TABLE.name} WHERE ${M.apartmentId} = ? AND ${M.role} = ? AND ${M.leftAt} IS NULL`,
    [apartmentId, MEMBERSHIP_ROLES.CONTRIBUTOR],
  );
}

export function listApartmentMembersStatement(apartmentId: string): SqlStatement {
  return createStatement(
    `SELECT m.${M.userId}, u.display_name, u.short_tag, u.color, m.${M.role}, m.${M.joinedAt}, m.${M.leftAt} FROM ${MEMBERSHIPS_TABLE.name} m INNER JOIN users u ON u.id = m.${M.userId} WHERE m.${M.apartmentId} = ? ORDER BY m.${M.leftAt} IS NOT NULL ASC, m.${M.joinedAt} ASC, m.${M.userId} ASC`,
    [apartmentId],
  );
}

export function insertContributorMembershipStatement(
  apartmentId: string,
  userId: string,
  joinedAt: string,
): SqlStatement {
  return createStatement(
    `INSERT INTO ${MEMBERSHIPS_TABLE.name} (${MEMBERSHIPS_TABLE.columnList()}) VALUES (?, ?, ?, ?, NULL)`,
    [apartmentId, userId, MEMBERSHIP_ROLES.CONTRIBUTOR, joinedAt],
  );
}

export function reactivateContributorMembershipStatement(
  apartmentId: string,
  userId: string,
  joinedAt: string,
): SqlStatement {
  return createStatement(
    `UPDATE ${MEMBERSHIPS_TABLE.name} SET ${M.role} = ?, ${M.joinedAt} = ?, ${M.leftAt} = NULL WHERE ${M.apartmentId} = ? AND ${M.userId} = ?`,
    [MEMBERSHIP_ROLES.CONTRIBUTOR, joinedAt, apartmentId, userId],
  );
}

export function markMembershipLeftStatement(
  apartmentId: string,
  userId: string,
  leftAt: string,
): SqlStatement {
  return createStatement(
    `UPDATE ${MEMBERSHIPS_TABLE.name} SET ${M.leftAt} = ? WHERE ${M.apartmentId} = ? AND ${M.userId} = ? AND ${M.leftAt} IS NULL`,
    [leftAt, apartmentId, userId],
  );
}

export function insertMembershipChangeLogStatement(
  apartmentId: string,
  userId: string,
  op: string,
  createdAt: string,
): SqlStatement {
  return createStatement(
    'INSERT INTO change_log (apartment_id, entity_type, entity_id, op, created_at) VALUES (?, ?, ?, ?, ?)',
    [apartmentId, MEMBERSHIP_CHANGE_LOG_ENTITY_TYPE, userId, op, createdAt],
  );
}
