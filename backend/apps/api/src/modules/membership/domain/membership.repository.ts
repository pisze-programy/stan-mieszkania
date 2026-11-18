import type { DomainError, Result } from '@stanmieszkania/shared';
import type {
  ApartmentMemberView,
  JoinableApartment,
  Membership,
  MembershipRole,
} from './membership.entity';

export interface JoinApartmentSummary {
  readonly apartment: JoinableApartment;
  readonly role: MembershipRole;
  readonly latestContributorJoinedAt: string | null;
}

export interface JoinAsContributorParams {
  readonly apartmentId: string;
  readonly userId: string;
  readonly joinedAt: string;
  readonly reactivateExisting: boolean;
}

export interface MarkMembershipLeftParams {
  readonly apartmentId: string;
  readonly userId: string;
  readonly leftAt: string;
  readonly op: 'revoked' | 'left';
}

export interface MembershipRepository {
  apartmentExists(apartmentId: string): Promise<Result<boolean, DomainError>>;
  findApartmentByInviteCode(
    inviteCode: string,
  ): Promise<Result<JoinableApartment | null, DomainError>>;
  findByApartmentAndUser(
    apartmentId: string,
    userId: string,
  ): Promise<Result<Membership | null, DomainError>>;
  getLatestContributorJoinedAt(apartmentId: string): Promise<Result<string | null, DomainError>>;
  listByApartment(
    apartmentId: string,
  ): Promise<Result<readonly ApartmentMemberView[], DomainError>>;
  joinAsContributor(params: JoinAsContributorParams): Promise<Result<void, DomainError>>;
  markLeft(params: MarkMembershipLeftParams): Promise<Result<void, DomainError>>;
}
