import { err, ok, type Clock, type DomainError, type Result } from '@stanmieszkania/shared';
import { normalizeInviteCode } from '../../apartments';
import type { InviteCodeRateLimiterPort } from '../domain/invite-rate-limiter.port';
import { MEMBERSHIP_CHANGE_LOG_OPS, MEMBERSHIP_ROLES } from '../domain/membership.constants';
import { isActiveMembership } from '../domain/membership.entity';
import {
  inviteCodeInvalidError,
  inviteCodeNotFoundError,
  membershipAccessDeniedError,
} from '../domain/membership.errors';
import type { JoinApartmentSummary, MembershipRepository } from '../domain/membership.repository';

export interface JoinApartmentByCodeDeps {
  readonly membershipRepository: MembershipRepository;
  readonly inviteRateLimiter: InviteCodeRateLimiterPort;
  readonly clock: Clock;
}

export interface JoinApartmentByCodeCommand {
  readonly userId: string;
  readonly inviteCode: string;
}

export interface JoinApartmentByCodeUseCase {
  execute(input: JoinApartmentByCodeCommand): Promise<Result<JoinApartmentSummary, DomainError>>;
}

export function createJoinApartmentByCodeUseCase(
  deps: JoinApartmentByCodeDeps,
): JoinApartmentByCodeUseCase {
  return {
    execute: async (input) => {
      const rateLimit = await deps.inviteRateLimiter.checkAndRecordJoinAttempt(input.userId);
      if (!rateLimit.ok) {
        return rateLimit;
      }

      const normalized = normalizeInviteCode(input.inviteCode);
      if (!normalized.ok) {
        return err(inviteCodeInvalidError(normalized.error.message));
      }

      const apartmentResult = await deps.membershipRepository.findApartmentByInviteCode(
        normalized.value,
      );
      if (!apartmentResult.ok) {
        return apartmentResult;
      }
      if (apartmentResult.value === null) {
        return err(inviteCodeNotFoundError());
      }

      const apartment = apartmentResult.value;
      const existingResult = await deps.membershipRepository.findByApartmentAndUser(
        apartment.id,
        input.userId,
      );
      if (!existingResult.ok) {
        return existingResult;
      }

      const existing = existingResult.value;
      if (existing !== null && isActiveMembership(existing)) {
        let latestContributorJoinedAt: string | null = null;
        if (existing.role === MEMBERSHIP_ROLES.OWNER) {
          const latest = await deps.membershipRepository.getLatestContributorJoinedAt(apartment.id);
          if (!latest.ok) {
            return latest;
          }
          latestContributorJoinedAt = latest.value;
        }
        return ok({ apartment, role: existing.role, latestContributorJoinedAt });
      }

      if (existing !== null && existing.leftAt !== null) {
        const departureOp = await deps.membershipRepository.findLatestMembershipDepartureOp(
          apartment.id,
          input.userId,
        );
        if (!departureOp.ok) {
          return departureOp;
        }
        // Decision Q9: Revoked contributors stay blocked until the Owner rotates the invite code.
        if (departureOp.value === MEMBERSHIP_CHANGE_LOG_OPS.REVOKED) {
          const rotatedAfterRevocation =
            apartment.inviteCodeRotatedAt !== null &&
            Date.parse(apartment.inviteCodeRotatedAt) > Date.parse(existing.leftAt);
          if (!rotatedAfterRevocation) {
            return err(membershipAccessDeniedError(apartment.id));
          }
        }
      }

      const joined = await deps.membershipRepository.joinAsContributor({
        apartmentId: apartment.id,
        userId: input.userId,
        joinedAt: deps.clock.nowIso(),
        reactivateExisting: existing !== null,
      });
      if (!joined.ok) {
        return joined;
      }

      return ok({
        apartment,
        role: MEMBERSHIP_ROLES.CONTRIBUTOR,
        latestContributorJoinedAt: null,
      });
    },
  };
}
