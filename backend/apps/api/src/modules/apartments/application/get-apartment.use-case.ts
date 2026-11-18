import { err, ok, type DomainError, type Result } from '@stanmieszkania/shared';
import type { ApartmentListEntry, ApartmentRepository } from '../domain/apartment.repository';
import { APARTMENT_ROLES } from '../domain/apartments.constants';
import { apartmentAccessDeniedError, apartmentNotFoundError } from '../domain/apartments.errors';

export interface GetApartmentDeps {
  readonly apartmentRepository: ApartmentRepository;
}

export interface GetApartmentQuery {
  readonly apartmentId: string;
  readonly userId: string;
}

export interface GetApartmentUseCase {
  execute(input: GetApartmentQuery): Promise<Result<ApartmentListEntry, DomainError>>;
}

export function createGetApartmentUseCase(deps: GetApartmentDeps): GetApartmentUseCase {
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

      let latestContributorJoinedAt: string | null = null;
      if (role.value === APARTMENT_ROLES.OWNER) {
        const latest = await deps.apartmentRepository.getLatestContributorJoinedAt(
          input.apartmentId,
        );
        if (!latest.ok) {
          return latest;
        }
        latestContributorJoinedAt = latest.value;
      }

      return ok({
        apartment: found.value,
        role: role.value,
        latestContributorJoinedAt,
      });
    },
  };
}
