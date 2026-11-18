import { createStatement, type SqlStatement } from '@stanmieszkania/d1';
import { z } from 'zod';
import { APARTMENT_ROLES } from '../domain/apartments.constants';
import { APARTMENT_CHANGES_TABLE } from './apartment-changes.table';
import { APARTMENTS_TABLE, apartmentRowSchema } from './apartments.table';

const A = APARTMENTS_TABLE.columns;
const AC = APARTMENT_CHANGES_TABLE.columns;

export const apartmentListRowSchema = apartmentRowSchema.extend({
  member_role: z.enum([APARTMENT_ROLES.OWNER, APARTMENT_ROLES.CONTRIBUTOR]),
  latest_contributor_joined_at: z.string().nullable(),
});

export const membershipRoleRowSchema = z.object({
  role: z.enum([APARTMENT_ROLES.OWNER, APARTMENT_ROLES.CONTRIBUTOR]),
});

export const latestJoinedRowSchema = z.object({
  latest_joined_at: z.string().nullable(),
});

export const activeContributorRowSchema = z.object({
  user_id: z.string(),
  joined_at: z.string(),
});

export const mediaR2KeyRowSchema = z.object({
  r2_key: z.string(),
});

export function findApartmentByIdStatement(id: string): SqlStatement {
  return createStatement(
    `SELECT ${APARTMENTS_TABLE.columnList()} FROM ${APARTMENTS_TABLE.name} WHERE ${A.id} = ? AND ${A.deletedAt} IS NULL LIMIT 1`,
    [id],
  );
}

// idx_apartments_invite_code is unique across all rows including soft-deleted apartments.
export function findApartmentByInviteCodeStatement(inviteCode: string): SqlStatement {
  return createStatement(
    `SELECT ${APARTMENTS_TABLE.columnList()} FROM ${APARTMENTS_TABLE.name} WHERE ${A.inviteCode} = ? LIMIT 1`,
    [inviteCode],
  );
}

export function findActiveMembershipRoleStatement(
  apartmentId: string,
  userId: string,
): SqlStatement {
  return createStatement(
    'SELECT role FROM memberships WHERE apartment_id = ? AND user_id = ? AND left_at IS NULL LIMIT 1',
    [apartmentId, userId],
  );
}

export function getLatestContributorJoinedAtStatement(apartmentId: string): SqlStatement {
  return createStatement(
    'SELECT MAX(joined_at) AS latest_joined_at FROM memberships WHERE apartment_id = ? AND role = ? AND left_at IS NULL',
    [apartmentId, APARTMENT_ROLES.CONTRIBUTOR],
  );
}

export function listActiveContributorsStatement(apartmentId: string): SqlStatement {
  return createStatement(
    'SELECT user_id, joined_at FROM memberships WHERE apartment_id = ? AND role = ? AND left_at IS NULL ORDER BY joined_at ASC, user_id ASC',
    [apartmentId, APARTMENT_ROLES.CONTRIBUTOR],
  );
}

export function listApartmentsForUserStatement(userId: string): SqlStatement {
  return createStatement(
    `SELECT ${APARTMENTS_TABLE.columnList('a')}, m.role AS member_role, (SELECT MAX(mc.joined_at) FROM memberships mc WHERE mc.apartment_id = a.${A.id} AND mc.role = ? AND mc.left_at IS NULL) AS latest_contributor_joined_at FROM ${APARTMENTS_TABLE.name} a INNER JOIN memberships m ON m.apartment_id = a.${A.id} WHERE m.user_id = ? AND m.left_at IS NULL AND a.${A.deletedAt} IS NULL ORDER BY a.${A.createdAt} DESC, a.${A.id} DESC`,
    [APARTMENT_ROLES.CONTRIBUTOR, userId],
  );
}

export function listApartmentChangesStatement(apartmentId: string): SqlStatement {
  return createStatement(
    `SELECT ${APARTMENT_CHANGES_TABLE.columnList()} FROM ${APARTMENT_CHANGES_TABLE.name} WHERE ${AC.apartmentId} = ? ORDER BY ${AC.createdAt} ASC, ${AC.id} ASC`,
    [apartmentId],
  );
}

export function listApartmentMediaR2KeysStatement(apartmentId: string): SqlStatement {
  return createStatement('SELECT r2_key FROM media WHERE apartment_id = ?', [apartmentId]);
}
