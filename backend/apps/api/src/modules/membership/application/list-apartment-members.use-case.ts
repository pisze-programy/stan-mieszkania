import { err, type DomainError, type Result } from '@stanmieszkania/shared';
import { isActiveMembership, type ApartmentMemberView } from '../domain/membership.entity';
import { membershipAccessDeniedError, membershipNotFoundError } from '../domain/membership.errors';
import type { MembershipRepository } from '../domain/membership.repository';

export interface ListApartmentMembersDeps {
  readonly membershipRepository: MembershipRepository;
}

export interface ListApartmentMembersQuery {
  readonly apartmentId: string;
  readonly userId: string;
}

export interface ListApartmentMembersUseCase {
  execute(
    input: ListApartmentMembersQuery,
  ): Promise<Result<readonly ApartmentMemberView[], DomainError>>;
}

export function createListApartmentMembersUseCase(
  deps: ListApartmentMembersDeps,
): ListApartmentMembersUseCase {
  return {
    execute: async (input) => {
      const exists = await deps.membershipRepository.apartmentExists(input.apartmentId);
      if (!exists.ok) {
        return exists;
      }
      if (!exists.value) {
        return err(membershipNotFoundError(input.apartmentId));
      }

      const caller = await deps.membershipRepository.findByApartmentAndUser(
        input.apartmentId,
        input.userId,
      );
      if (!caller.ok) {
        return caller;
      }
      if (caller.value === null || !isActiveMembership(caller.value)) {
        return err(membershipAccessDeniedError(input.apartmentId));
      }

      return deps.membershipRepository.listByApartment(input.apartmentId);
    },
  };
}
