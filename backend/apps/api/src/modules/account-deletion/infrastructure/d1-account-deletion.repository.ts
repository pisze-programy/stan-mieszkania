import {
  execute,
  executeBatch,
  query,
  type D1Client,
  type D1PreparedStatementLike,
  type D1Queryable,
} from '@stanmieszkania/d1';
import { mapResult, ok } from '@stanmieszkania/shared';
import type {
  AccountDeletionRepository,
  UserApartmentContext,
} from '../domain/account-deletion.repository';
import {
  activeContributorRowSchema,
  anonymizeUserPreservingUidStatement,
  hardDeletePrivateApartmentStatements,
  leaveAsContributorStatements,
  listActiveContributorsStatement,
  listApartmentMediaR2KeysStatement,
  listUserApartmentMembershipsStatement,
  mediaR2KeyRowSchema,
  scheduleOrphanDeleteAndLeaveStatements,
  transferOwnershipAndLeaveStatements,
  userApartmentMembershipRowSchema,
} from './account-deletion.queries';

export function createD1AccountDeletionRepository<
  TStatement extends D1PreparedStatementLike<TStatement>,
>(db: D1Client<TStatement> & D1Queryable): AccountDeletionRepository {
  return {
    listUserApartments: async (userId) => {
      const membershipsResult = await query(
        db,
        listUserApartmentMembershipsStatement(userId),
        userApartmentMembershipRowSchema,
      );
      if (!membershipsResult.ok) {
        return membershipsResult;
      }

      const contexts: UserApartmentContext[] = [];
      for (const row of membershipsResult.value) {
        const contributorsResult = await query(
          db,
          listActiveContributorsStatement(row.apartment_id),
          activeContributorRowSchema,
        );
        if (!contributorsResult.ok) {
          return contributorsResult;
        }

        const r2KeysResult = await query(
          db,
          listApartmentMediaR2KeysStatement(row.apartment_id),
          mediaR2KeyRowSchema,
        );
        if (!r2KeysResult.ok) {
          return r2KeysResult;
        }

        contexts.push({
          apartmentId: row.apartment_id,
          role: row.role,
          isActiveMembership: row.left_at === null,
          activeContributors: contributorsResult.value.map((contributor) => ({
            userId: contributor.user_id,
            joinedAt: contributor.joined_at,
          })),
          hasSharedHistory: row.has_shared_history === 1,
          mediaR2Keys: r2KeysResult.value.map((media) => media.r2_key),
        });
      }

      return ok(contexts);
    },

    hardDeletePrivateApartment: async (apartmentId) => {
      const result = await executeBatch(db, hardDeletePrivateApartmentStatements(apartmentId));
      return mapResult(result, () => undefined);
    },

    transferOwnershipAndLeave: async (params) => {
      const result = await executeBatch(
        db,
        transferOwnershipAndLeaveStatements(
          params.apartmentId,
          params.previousOwnerId,
          params.newOwnerId,
          params.leftAt,
        ),
      );
      return mapResult(result, () => undefined);
    },

    scheduleOrphanDeleteAndLeave: async (params) => {
      const result = await executeBatch(
        db,
        scheduleOrphanDeleteAndLeaveStatements(
          params.apartmentId,
          params.ownerId,
          params.orphanDeleteAfter,
          params.leftAt,
        ),
      );
      return mapResult(result, () => undefined);
    },

    leaveAsContributor: async (params) => {
      const result = await executeBatch(
        db,
        leaveAsContributorStatements(params.apartmentId, params.userId, params.leftAt),
      );
      return mapResult(result, () => undefined);
    },

    anonymizeUserPreservingUid: async (userId, displayName, deletedAt) => {
      const result = await execute(
        db,
        anonymizeUserPreservingUidStatement(userId, displayName, deletedAt),
      );
      return mapResult(result, () => undefined);
    },
  };
}
