import type { DomainError, Result } from '@stanmieszkania/shared';
import type { ApartmentChange } from './apartment-change.entity';
import type { Apartment } from './apartment.entity';

export type ApartmentMemberRole = 'owner' | 'contributor';

export interface ApartmentListEntry {
  readonly apartment: Apartment;
  readonly role: ApartmentMemberRole;
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

export interface ApartmentRepository {
  findById(id: string): Promise<Result<Apartment | null, DomainError>>;
  findByInviteCode(inviteCode: string): Promise<Result<Apartment | null, DomainError>>;
  listForUser(userId: string): Promise<Result<readonly ApartmentListEntry[], DomainError>>;
  createWithOwnerMembership(
    params: CreateApartmentWithOwnerParams,
  ): Promise<Result<void, DomainError>>;
  updateWithChanges(params: UpdateApartmentWithChangesParams): Promise<Result<void, DomainError>>;
  rotateInviteCode(params: RotateInviteCodeParams): Promise<Result<void, DomainError>>;
  transferOwnershipAndLeave(
    params: TransferOwnershipAndLeaveParams,
  ): Promise<Result<void, DomainError>>;
  hardDelete(apartmentId: string): Promise<Result<void, DomainError>>;
  listChanges(apartmentId: string): Promise<Result<readonly ApartmentChange[], DomainError>>;
}
