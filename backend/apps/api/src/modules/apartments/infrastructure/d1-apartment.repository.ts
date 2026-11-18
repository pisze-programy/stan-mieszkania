import {
  executeBatch,
  query,
  queryFirst,
  type D1Client,
  type D1PreparedStatementLike,
  type D1Queryable,
} from '@stanmieszkania/d1';
import { mapResult } from '@stanmieszkania/shared';
import type { ApartmentRepository } from '../domain/apartment.repository';
import { CHANGE_LOG_ENTITY_TYPES, CHANGE_LOG_OPS } from '../domain/apartments.constants';
import { APARTMENT_CHANGES_TABLE } from './apartment-changes.table';
import {
  hardDeleteApartmentStatements,
  insertApartmentChangeStatement,
  insertApartmentStatement,
  insertChangeLogStatement,
  insertOwnerMembershipStatement,
  leaveAsContributorStatements,
  transferOwnershipAndLeaveStatements,
  updateApartmentMetadataStatement,
  updateInviteCodeStatement,
} from './apartment-mutations.queries';
import {
  mapApartmentChangeEntityToRow,
  mapApartmentChangeRowToEntity,
  mapApartmentEntityToRow,
  mapApartmentRowToEntity,
} from './apartment-row.mapper';
import {
  activeContributorRowSchema,
  apartmentListRowSchema,
  findActiveMembershipRoleStatement,
  findApartmentByIdStatement,
  findApartmentByInviteCodeStatement,
  getLatestContributorJoinedAtStatement,
  latestJoinedRowSchema,
  listActiveContributorsStatement,
  listApartmentChangesStatement,
  listApartmentMediaR2KeysStatement,
  listApartmentsForUserStatement,
  mediaR2KeyRowSchema,
  membershipRoleRowSchema,
} from './apartments.queries';
import { APARTMENTS_TABLE } from './apartments.table';

export function createD1ApartmentRepository<TStatement extends D1PreparedStatementLike<TStatement>>(
  db: D1Client<TStatement> & D1Queryable,
): ApartmentRepository {
  return {
    findById: async (id) => {
      const result = await queryFirst(
        db,
        findApartmentByIdStatement(id),
        APARTMENTS_TABLE.rowSchema,
      );
      return mapResult(result, (row) => (row === null ? null : mapApartmentRowToEntity(row)));
    },
    findByInviteCode: async (inviteCode) => {
      const result = await queryFirst(
        db,
        findApartmentByInviteCodeStatement(inviteCode),
        APARTMENTS_TABLE.rowSchema,
      );
      return mapResult(result, (row) => (row === null ? null : mapApartmentRowToEntity(row)));
    },
    findActiveRole: async (apartmentId, userId) => {
      const result = await queryFirst(
        db,
        findActiveMembershipRoleStatement(apartmentId, userId),
        membershipRoleRowSchema,
      );
      return mapResult(result, (row) => (row === null ? null : row.role));
    },
    getLatestContributorJoinedAt: async (apartmentId) => {
      const result = await queryFirst(
        db,
        getLatestContributorJoinedAtStatement(apartmentId),
        latestJoinedRowSchema,
      );
      return mapResult(result, (row) => row?.latest_joined_at ?? null);
    },
    listActiveContributors: async (apartmentId) => {
      const result = await query(
        db,
        listActiveContributorsStatement(apartmentId),
        activeContributorRowSchema,
      );
      return mapResult(result, (rows) =>
        rows.map((row) => ({ userId: row.user_id, joinedAt: row.joined_at })),
      );
    },
    listForUser: async (userId) => {
      const result = await query(
        db,
        listApartmentsForUserStatement(userId),
        apartmentListRowSchema,
      );
      return mapResult(result, (rows) =>
        rows.map((row) => ({
          apartment: mapApartmentRowToEntity(row),
          role: row.member_role,
          latestContributorJoinedAt: row.latest_contributor_joined_at,
        })),
      );
    },
    createWithOwnerMembership: async ({ apartment, joinedAt }) => {
      const row = mapApartmentEntityToRow(apartment);
      const result = await executeBatch(db, [
        insertApartmentStatement(row),
        insertOwnerMembershipStatement(apartment.id, apartment.ownerId, joinedAt),
        insertChangeLogStatement(
          apartment.id,
          CHANGE_LOG_ENTITY_TYPES.APARTMENT,
          apartment.id,
          CHANGE_LOG_OPS.CREATED,
          joinedAt,
        ),
      ]);
      return mapResult(result, () => undefined);
    },
    updateWithChanges: async ({ apartment, changes }) => {
      const row = mapApartmentEntityToRow(apartment);
      const result = await executeBatch(db, [
        updateApartmentMetadataStatement(row),
        ...changes.map((change) =>
          insertApartmentChangeStatement(mapApartmentChangeEntityToRow(change)),
        ),
        insertChangeLogStatement(
          apartment.id,
          CHANGE_LOG_ENTITY_TYPES.APARTMENT,
          apartment.id,
          CHANGE_LOG_OPS.UPDATED,
          apartment.updatedAt,
        ),
      ]);
      return mapResult(result, () => undefined);
    },
    rotateInviteCode: async ({ apartmentId, inviteCode, rotatedAt }) => {
      const result = await executeBatch(db, [
        updateInviteCodeStatement(apartmentId, inviteCode, rotatedAt),
        insertChangeLogStatement(
          apartmentId,
          CHANGE_LOG_ENTITY_TYPES.APARTMENT,
          apartmentId,
          CHANGE_LOG_OPS.INVITE_CODE_ROTATED,
          rotatedAt,
        ),
      ]);
      return mapResult(result, () => undefined);
    },
    transferOwnershipAndLeave: async ({ apartmentId, previousOwnerId, newOwnerId, leftAt }) => {
      const result = await executeBatch(
        db,
        transferOwnershipAndLeaveStatements(apartmentId, previousOwnerId, newOwnerId, leftAt),
      );
      return mapResult(result, () => undefined);
    },
    leaveAsContributor: async ({ apartmentId, userId, leftAt }) => {
      const result = await executeBatch(
        db,
        leaveAsContributorStatements(apartmentId, userId, leftAt),
      );
      return mapResult(result, () => undefined);
    },
    listMediaR2Keys: async (apartmentId) => {
      const result = await query(
        db,
        listApartmentMediaR2KeysStatement(apartmentId),
        mediaR2KeyRowSchema,
      );
      return mapResult(result, (rows) => rows.map((row) => row.r2_key));
    },
    hardDelete: async (apartmentId) => {
      const result = await executeBatch(db, hardDeleteApartmentStatements(apartmentId));
      return mapResult(result, () => undefined);
    },
    listChanges: async (apartmentId) => {
      const result = await query(
        db,
        listApartmentChangesStatement(apartmentId),
        APARTMENT_CHANGES_TABLE.rowSchema,
      );
      return mapResult(result, (rows) => rows.map(mapApartmentChangeRowToEntity));
    },
  };
}
