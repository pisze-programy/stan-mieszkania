import {
  err,
  ok,
  type Clock,
  type DomainError,
  type IdGenerator,
  type Result,
} from '@stanmieszkania/shared';
import { applyApartmentMetadataUpdate } from '../domain/apartment.entity';
import type { ApartmentListEntry, ApartmentRepository } from '../domain/apartment.repository';
import { APARTMENT_ROLES } from '../domain/apartments.constants';
import {
  apartmentAccessDeniedError,
  apartmentNotFoundError,
  apartmentOwnerRequiredError,
} from '../domain/apartments.errors';

export interface UpdateApartmentDeps {
  readonly apartmentRepository: ApartmentRepository;
  readonly clock: Clock;
  readonly idGenerator: IdGenerator;
}

export interface UpdateApartmentCommand {
  readonly apartmentId: string;
  readonly userId: string;
  readonly name?: string;
  readonly street?: string;
  readonly city?: string;
}

export interface UpdateApartmentUseCase {
  execute(input: UpdateApartmentCommand): Promise<Result<ApartmentListEntry, DomainError>>;
}

export function createUpdateApartmentUseCase(deps: UpdateApartmentDeps): UpdateApartmentUseCase {
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
      if (role.value !== APARTMENT_ROLES.OWNER) {
        return err(apartmentOwnerRequiredError(input.apartmentId));
      }

      const updated = applyApartmentMetadataUpdate({
        apartment: found.value,
        authorId: input.userId,
        ...(input.name !== undefined ? { name: input.name } : {}),
        ...(input.street !== undefined ? { street: input.street } : {}),
        ...(input.city !== undefined ? { city: input.city } : {}),
        updatedAt: deps.clock.nowIso(),
        idGenerator: deps.idGenerator,
      });
      if (!updated.ok) {
        return updated;
      }

      if (updated.value.changes.length > 0) {
        const persisted = await deps.apartmentRepository.updateWithChanges({
          apartment: updated.value.apartment,
          changes: updated.value.changes,
        });
        if (!persisted.ok) {
          return persisted;
        }
      }

      const latest = await deps.apartmentRepository.getLatestContributorJoinedAt(input.apartmentId);
      if (!latest.ok) {
        return latest;
      }

      return ok({
        apartment: updated.value.apartment,
        role: APARTMENT_ROLES.OWNER,
        latestContributorJoinedAt: latest.value,
      });
    },
  };
}
