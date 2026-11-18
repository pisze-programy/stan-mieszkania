import { err, type Clock, type DomainError, type Result } from '@stanmieszkania/shared';
import { MEMBERSHIP_CHANGE_LOG_OPS, MEMBERSHIP_ROLES } from '../domain/membership.constants';
import { isActiveMembership } from '../domain/membership.entity';
import {
  cannotRevokeOwnerError,
  membershipAccessDeniedError,
  membershipNotFoundError,
  membershipOwnerRequiredError,
} from '../domain/membership.errors';
import type { MembershipRepository } from '../domain/membership.repository';

export interface RevokeMemberAccessDeps {
  readonly membershipRepository: MembershipRepository;
  readonly clock: Clock;
}

export interface RevokeMemberAccessCommand {
  readonly apartmentId: string;
  readonly actorUserId: string;
  readonly targetUserId: string;
}

export interface RevokeMemberAccessUseCase {
  execute(input: RevokeMemberAccessCommand): Promise<Result<void, DomainError>>;
}

export function createRevokeMemberAccessUseCase(
  deps: RevokeMemberAccessDeps,
): RevokeMemberAccessUseCase {
  return {
    execute: async (input) => {
      const exists = await deps.membershipRepository.apartmentExists(input.apartmentId);
      if (!exists.ok) {
        return exists;
      }
      if (!exists.value) {
        return err(membershipNotFoundError(input.apartmentId));
      }

      const actor = await deps.membershipRepository.findByApartmentAndUser(
        input.apartmentId,
        input.actorUserId,
      );
      if (!actor.ok) {
        return actor;
      }
      if (actor.value === null || !isActiveMembership(actor.value)) {
        return err(membershipAccessDeniedError(input.apartmentId));
      }
      if (actor.value.role !== MEMBERSHIP_ROLES.OWNER) {
        return err(membershipOwnerRequiredError(input.apartmentId));
      }

      const target = await deps.membershipRepository.findByApartmentAndUser(
        input.apartmentId,
        input.targetUserId,
      );
      if (!target.ok) {
        return target;
      }
      if (target.value === null || !isActiveMembership(target.value)) {
        return err(membershipNotFoundError(input.apartmentId, input.targetUserId));
      }
      if (target.value.role === MEMBERSHIP_ROLES.OWNER) {
        return err(cannotRevokeOwnerError(input.apartmentId));
      }

      return deps.membershipRepository.markLeft({
        apartmentId: input.apartmentId,
        userId: input.targetUserId,
        leftAt: deps.clock.nowIso(),
        op: MEMBERSHIP_CHANGE_LOG_OPS.REVOKED,
      });
    },
  };
}
