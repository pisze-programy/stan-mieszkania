import type { DomainError, Result } from '@stanmieszkania/shared';

export interface ActiveApartmentContributor {
  readonly userId: string;
  readonly joinedAt: string;
}

export interface UserApartmentContext {
  readonly apartmentId: string;
  readonly role: 'owner' | 'contributor';
  readonly isActiveMembership: boolean;
  readonly activeContributors: readonly ActiveApartmentContributor[];
  readonly hasSharedHistory: boolean;
  readonly mediaR2Keys: readonly string[];
}

export interface TransferApartmentOwnershipParams {
  readonly apartmentId: string;
  readonly previousOwnerId: string;
  readonly newOwnerId: string;
  readonly leftAt: string;
}

export interface ScheduleOrphanDeleteParams {
  readonly apartmentId: string;
  readonly ownerId: string;
  readonly orphanDeleteAfter: string;
  readonly leftAt: string;
}

export interface LeaveApartmentAsContributorParams {
  readonly apartmentId: string;
  readonly userId: string;
  readonly leftAt: string;
}

export interface AccountDeletionRepository {
  listUserApartments(userId: string): Promise<Result<readonly UserApartmentContext[], DomainError>>;
  hardDeletePrivateApartment(apartmentId: string): Promise<Result<void, DomainError>>;
  transferOwnershipAndLeave(
    params: TransferApartmentOwnershipParams,
  ): Promise<Result<void, DomainError>>;
  scheduleOrphanDeleteAndLeave(
    params: ScheduleOrphanDeleteParams,
  ): Promise<Result<void, DomainError>>;
  leaveAsContributor(params: LeaveApartmentAsContributorParams): Promise<Result<void, DomainError>>;
  anonymizeUserPreservingUid(
    userId: string,
    displayName: string,
    deletedAt: string,
  ): Promise<Result<void, DomainError>>;
}
