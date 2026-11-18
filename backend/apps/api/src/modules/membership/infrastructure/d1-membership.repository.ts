import {
  executeBatch,
  query,
  queryFirst,
  type D1Client,
  type D1PreparedStatementLike,
  type D1Queryable,
} from '@stanmieszkania/d1';
import { mapResult } from '@stanmieszkania/shared';
import { apartmentRowSchema } from '../../apartments';
import { MEMBERSHIP_CHANGE_LOG_OPS } from '../domain/membership.constants';
import type { MembershipRepository } from '../domain/membership.repository';
import {
  mapApartmentRowToJoinable,
  mapMembershipRowToEntity,
  mapMemberViewRowToView,
} from './membership-row.mapper';
import {
  apartmentIdOnlyRowSchema,
  findActiveApartmentIdStatement,
  findApartmentByInviteCodeStatement,
  findMembershipStatement,
  getLatestContributorJoinedAtStatement,
  insertContributorMembershipStatement,
  insertMembershipChangeLogStatement,
  latestJoinedAtRowSchema,
  listApartmentMembersStatement,
  markMembershipLeftStatement,
  memberViewRowSchema,
  reactivateContributorMembershipStatement,
} from './memberships.queries';
import { MEMBERSHIPS_TABLE } from './memberships.table';

export function createD1MembershipRepository<
  TStatement extends D1PreparedStatementLike<TStatement>,
>(db: D1Client<TStatement> & D1Queryable): MembershipRepository {
  return {
    apartmentExists: async (apartmentId) => {
      const result = await queryFirst(
        db,
        findActiveApartmentIdStatement(apartmentId),
        apartmentIdOnlyRowSchema,
      );
      return mapResult(result, (row) => row !== null);
    },
    findApartmentByInviteCode: async (inviteCode) => {
      const result = await queryFirst(
        db,
        findApartmentByInviteCodeStatement(inviteCode),
        apartmentRowSchema,
      );
      return mapResult(result, (row) => (row === null ? null : mapApartmentRowToJoinable(row)));
    },
    findByApartmentAndUser: async (apartmentId, userId) => {
      const result = await queryFirst(
        db,
        findMembershipStatement(apartmentId, userId),
        MEMBERSHIPS_TABLE.rowSchema,
      );
      return mapResult(result, (row) => (row === null ? null : mapMembershipRowToEntity(row)));
    },
    getLatestContributorJoinedAt: async (apartmentId) => {
      const result = await queryFirst(
        db,
        getLatestContributorJoinedAtStatement(apartmentId),
        latestJoinedAtRowSchema,
      );
      return mapResult(result, (row) => row?.latest_joined_at ?? null);
    },
    listByApartment: async (apartmentId) => {
      const result = await query(
        db,
        listApartmentMembersStatement(apartmentId),
        memberViewRowSchema,
      );
      return mapResult(result, (rows) => rows.map(mapMemberViewRowToView));
    },
    joinAsContributor: async ({ apartmentId, userId, joinedAt, reactivateExisting }) => {
      const membershipStmt = reactivateExisting
        ? reactivateContributorMembershipStatement(apartmentId, userId, joinedAt)
        : insertContributorMembershipStatement(apartmentId, userId, joinedAt);
      const result = await executeBatch(db, [
        membershipStmt,
        insertMembershipChangeLogStatement(
          apartmentId,
          userId,
          MEMBERSHIP_CHANGE_LOG_OPS.JOINED,
          joinedAt,
        ),
      ]);
      return mapResult(result, () => undefined);
    },
    markLeft: async ({ apartmentId, userId, leftAt, op }) => {
      const result = await executeBatch(db, [
        markMembershipLeftStatement(apartmentId, userId, leftAt),
        insertMembershipChangeLogStatement(apartmentId, userId, op, leftAt),
      ]);
      return mapResult(result, () => undefined);
    },
  };
}
