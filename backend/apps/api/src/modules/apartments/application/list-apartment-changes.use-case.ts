import { err, type DomainError, type Result } from '@stanmieszkania/shared';
import type { ApartmentChange } from '../domain/apartment-change.entity';
import type { ApartmentRepository } from '../domain/apartment.repository';
import { apartmentAccessDeniedError, apartmentNotFoundError } from '../domain/apartments.errors';

export interface ListApartmentChangesDeps {
  readonly apartmentRepository: ApartmentRepository;
}

export interface ListApartmentChangesQuery {
  readonly apartmentId: string;
  readonly userId: string;
}

export interface ListApartmentChangesUseCase {
  execute(
    input: ListApartmentChangesQuery,
  ): Promise<Result<readonly ApartmentChange[], DomainError>>;
}

export function createListApartmentChangesUseCase(
  deps: ListApartmentChangesDeps,
): ListApartmentChangesUseCase {
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

      return deps.apartmentRepository.listChanges(input.apartmentId);
    },
  };
}
