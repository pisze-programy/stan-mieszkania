import type { DomainError, Result } from '@stanmieszkania/shared';
import type { MyApartmentSyncSummary, SyncChangesPage, SyncRole } from './sync.entity';

export interface SyncApartmentAccess {
  readonly apartmentId: string;
  readonly role: SyncRole;
  readonly isActiveMember: boolean;
}

export interface ListChangesAfterQuery {
  readonly apartmentId: string;
  readonly callerUserId: string;
  readonly callerRole: SyncRole;
  readonly afterSeq: number;
  readonly limit: number;
}

export interface SyncRepository {
  findApartmentAccess(
    apartmentId: string,
    userId: string,
  ): Promise<Result<SyncApartmentAccess | null, DomainError>>;
  listChangesAfter(query: ListChangesAfterQuery): Promise<Result<SyncChangesPage, DomainError>>;
  listMyApartmentsSync(
    userId: string,
  ): Promise<Result<readonly MyApartmentSyncSummary[], DomainError>>;
}
