import type { DomainError, Result } from '@stanmieszkania/shared';
import type { ApartmentChange } from './apartment-change.entity';
import type { Apartment } from './apartment.entity';
import type { ActiveContributor } from './ownership-transfer.policy';

export type ApartmentMemberRole = 'owner' | 'contributor';

export interface ApartmentListEntry {
  readonly apartment: Apartment;
  readonly role: ApartmentMemberRole;
  readonly latestContributorJoinedAt: string | null;
}

export interface CreateApartmentWithOwnerParams {
  readonly apartment: Apartment;
  readonly joinedAt: string;
}

export interface UpdateApartmentWithChangesParams {
  readonly apartment: Apartment;
  readonly changes: readonly ApartmentChange[];
}

export interface RotateInviteCodeParams {
  readonly apartmentId: string;
  readonly inviteCode: string;
  readonly rotatedAt: string;
}

export interface TransferOwnershipAndLeaveParams {
  readonly apartmentId: string;
  readonly previousOwnerId: string;
  readonly newOwnerId: string;
  readonly leftAt: string;
}

export interface LeaveAsContributorParams {
  readonly apartmentId: string;
  readonly userId: string;
  readonly leftAt: string;
}

export interface ApartmentRepository {
  findById(id: string): Promise<Result<Apartment | null, DomainError>>;
  findByInviteCode(inviteCode: string): Promise<Result<Apartment | null, DomainError>>;
  findActiveRole(
    apartmentId: string,
    userId: string,
  ): Promise<Result<ApartmentMemberRole | null, DomainError>>;
  getLatestContributorJoinedAt(apartmentId: string): Promise<Result<string | null, DomainError>>;
  listActiveContributors(
    apartmentId: string,
  ): Promise<Result<readonly ActiveContributor[], DomainError>>;
  listForUser(userId: string): Promise<Result<readonly ApartmentListEntry[], DomainError>>;
  createWithOwnerMembership(
    params: CreateApartmentWithOwnerParams,
  ): Promise<Result<void, DomainError>>;
  updateWithChanges(params: UpdateApartmentWithChangesParams): Promise<Result<void, DomainError>>;
  rotateInviteCode(params: RotateInviteCodeParams): Promise<Result<void, DomainError>>;
  transferOwnershipAndLeave(
    params: TransferOwnershipAndLeaveParams,
  ): Promise<Result<void, DomainError>>;
  leaveAsContributor(params: LeaveAsContributorParams): Promise<Result<void, DomainError>>;
  listMediaR2Keys(apartmentId: string): Promise<Result<readonly string[], DomainError>>;
  hardDelete(apartmentId: string): Promise<Result<void, DomainError>>;
  listChanges(apartmentId: string): Promise<Result<readonly ApartmentChange[], DomainError>>;
}
