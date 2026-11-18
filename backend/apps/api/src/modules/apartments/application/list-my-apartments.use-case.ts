import type { DomainError, Result } from '@stanmieszkania/shared';
import type { ApartmentListEntry, ApartmentRepository } from '../domain/apartment.repository';

export interface ListMyApartmentsDeps {
  readonly apartmentRepository: ApartmentRepository;
}

export interface ListMyApartmentsUseCase {
  execute(userId: string): Promise<Result<readonly ApartmentListEntry[], DomainError>>;
}

export function createListMyApartmentsUseCase(deps: ListMyApartmentsDeps): ListMyApartmentsUseCase {
  return {
    execute: (userId) => deps.apartmentRepository.listForUser(userId),
  };
}
