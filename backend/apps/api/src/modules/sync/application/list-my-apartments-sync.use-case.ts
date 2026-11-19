import type { DomainError, Result } from '@stanmieszkania/shared';
import type { MyApartmentSyncSummary } from '../domain/sync.entity';
import type { SyncRepository } from '../domain/sync.repository';

export interface ListMyApartmentsSyncDeps {
  readonly syncRepository: SyncRepository;
}

export interface ListMyApartmentsSyncUseCase {
  execute(userId: string): Promise<Result<readonly MyApartmentSyncSummary[], DomainError>>;
}

export function createListMyApartmentsSyncUseCase(
  deps: ListMyApartmentsSyncDeps,
): ListMyApartmentsSyncUseCase {
  return {
    execute: (userId) => deps.syncRepository.listMyApartmentsSync(userId),
  };
}
