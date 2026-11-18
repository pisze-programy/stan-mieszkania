import { err, type Clock, type DomainError, type Result } from '@stanmieszkania/shared';
import type { ApartmentRepository } from '../domain/apartment.repository';
import { APARTMENT_ROLES } from '../domain/apartments.constants';
import { apartmentAccessDeniedError, apartmentNotFoundError } from '../domain/apartments.errors';
import { resolveOwnerDeparture } from '../domain/ownership-transfer.policy';

export interface DeleteOrLeaveApartmentDeps {
  readonly apartmentRepository: ApartmentRepository;
  readonly clock: Clock;
}

export interface DeleteOrLeaveApartmentCommand {
  readonly apartmentId: string;
  readonly userId: string;
}

export interface DeleteOrLeaveApartmentUseCase {
  execute(input: DeleteOrLeaveApartmentCommand): Promise<Result<void, DomainError>>;
}

export function createDeleteOrLeaveApartmentUseCase(
  deps: DeleteOrLeaveApartmentDeps,
): DeleteOrLeaveApartmentUseCase {
  return {
    execute: async (input) => {
      const found = await deps.apartmentRepository.findById(input.apartmentId);
      if (!found.ok) {
        return found;
      }
      if (found.value === null) {
        return err(apartmentNotFoundError(input.apartmentId));
      }

      const role = await deps.apartmentRepository.findActiveRole(input.apartmentId, input.userId);
      if (!role.ok) {
        return role;
      }
      if (role.value === null) {
        return err(apartmentAccessDeniedError(input.apartmentId));
      }

      const nowIso = deps.clock.nowIso();

      if (role.value === APARTMENT_ROLES.CONTRIBUTOR) {
        return deps.apartmentRepository.leaveAsContributor({
          apartmentId: input.apartmentId,
          userId: input.userId,
          leftAt: nowIso,
        });
      }

      const contributors = await deps.apartmentRepository.listActiveContributors(input.apartmentId);
      if (!contributors.ok) {
        return contributors;
      }

      const resolution = resolveOwnerDeparture({
        activeContributors: contributors.value,
        hasSharedHistory: false,
        trigger: 'owner_delete_or_leave',
        nowMs: deps.clock.nowMs(),
      });

      if (resolution.action === 'transfer') {
        return deps.apartmentRepository.transferOwnershipAndLeave({
          apartmentId: input.apartmentId,
          previousOwnerId: input.userId,
          newOwnerId: resolution.newOwnerId,
          leftAt: nowIso,
        });
      }

      return deps.apartmentRepository.hardDelete(input.apartmentId);
    },
  };
}
