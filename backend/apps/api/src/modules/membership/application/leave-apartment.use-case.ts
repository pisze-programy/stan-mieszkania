import { err, type Clock, type DomainError, type Result } from '@stanmieszkania/shared';
import { MEMBERSHIP_CHANGE_LOG_OPS, MEMBERSHIP_ROLES } from '../domain/membership.constants';
import { isActiveMembership } from '../domain/membership.entity';
import {
  cannotRevokeOwnerError,
  membershipAccessDeniedError,
  membershipNotFoundError,
} from '../domain/membership.errors';
import type { MembershipRepository } from '../domain/membership.repository';

export interface LeaveApartmentDeps {
  readonly membershipRepository: MembershipRepository;
  readonly clock: Clock;
}

export interface LeaveApartmentCommand {
  readonly apartmentId: string;
  readonly userId: string;
}

export interface LeaveApartmentUseCase {
  execute(input: LeaveApartmentCommand): Promise<Result<void, DomainError>>;
}

export function createLeaveApartmentUseCase(deps: LeaveApartmentDeps): LeaveApartmentUseCase {
  return {
    execute: async (input) => {
      const exists = await deps.membershipRepository.apartmentExists(input.apartmentId);
      if (!exists.ok) {
        return exists;
      }
      if (!exists.value) {
        return err(membershipNotFoundError(input.apartmentId));
      }

      const membership = await deps.membershipRepository.findByApartmentAndUser(
        input.apartmentId,
        input.userId,
      );
      if (!membership.ok) {
        return membership;
      }
      if (membership.value === null || !isActiveMembership(membership.value)) {
        return err(membershipAccessDeniedError(input.apartmentId));
      }
      // Decision S2-9: Owners transfer or delete via DELETE /v1/apartments/{id}, never plain leave.
      if (membership.value.role === MEMBERSHIP_ROLES.OWNER) {
        return err(cannotRevokeOwnerError(input.apartmentId));
      }

      return deps.membershipRepository.markLeft({
        apartmentId: input.apartmentId,
        userId: input.userId,
        leftAt: deps.clock.nowIso(),
        op: MEMBERSHIP_CHANGE_LOG_OPS.LEFT,
      });
    },
  };
}
