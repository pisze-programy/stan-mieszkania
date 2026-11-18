import { ok, type DomainError, type Result } from '@stanmieszkania/shared';
import { MEMBERSHIP_ROLES } from '../domain/membership.constants';
import type {
  ApartmentMemberView,
  JoinableApartment,
  Membership,
} from '../domain/membership.entity';
import type {
  JoinAsContributorParams,
  MarkMembershipLeftParams,
  MembershipRepository,
} from '../domain/membership.repository';

export interface InMemoryUserProfile {
  readonly id: string;
  readonly displayName: string;
  readonly shortTag: string;
  readonly color: string;
}

export class InMemoryMembershipRepository implements MembershipRepository {
  private readonly apartments = new Map<string, JoinableApartment>();
  private readonly users = new Map<string, InMemoryUserProfile>();
  private readonly memberships = new Map<string, Membership>();
  public readonly changeLog: Array<{
    readonly apartmentId: string;
    readonly userId: string;
    readonly op: string;
    readonly createdAt: string;
  }> = [];

  private static key(apartmentId: string, userId: string): string {
    return `${apartmentId}:${userId}`;
  }

  public seedUser(user: InMemoryUserProfile): void {
    this.users.set(user.id, user);
  }

  public seedApartment(apartment: JoinableApartment, ownerJoinedAt?: string): void {
    this.apartments.set(apartment.id, apartment);
    this.memberships.set(InMemoryMembershipRepository.key(apartment.id, apartment.ownerId), {
      apartmentId: apartment.id,
      userId: apartment.ownerId,
      role: MEMBERSHIP_ROLES.OWNER,
      joinedAt: ownerJoinedAt ?? apartment.createdAt,
      leftAt: null,
    });
  }

  public apartmentExists(apartmentId: string): Promise<Result<boolean, DomainError>> {
    return Promise.resolve(ok(this.apartments.has(apartmentId)));
  }

  public findApartmentByInviteCode(
    inviteCode: string,
  ): Promise<Result<JoinableApartment | null, DomainError>> {
    const found =
      Array.from(this.apartments.values()).find((apt) => apt.inviteCode === inviteCode) ?? null;
    return Promise.resolve(ok(found));
  }

  public findByApartmentAndUser(
    apartmentId: string,
    userId: string,
  ): Promise<Result<Membership | null, DomainError>> {
    return Promise.resolve(
      ok(this.memberships.get(InMemoryMembershipRepository.key(apartmentId, userId)) ?? null),
    );
  }

  public getLatestContributorJoinedAt(
    apartmentId: string,
  ): Promise<Result<string | null, DomainError>> {
    const joinedAts = Array.from(this.memberships.values())
      .filter(
        (m) =>
          m.apartmentId === apartmentId &&
          m.role === MEMBERSHIP_ROLES.CONTRIBUTOR &&
          m.leftAt === null,
      )
      .map((m) => m.joinedAt)
      .sort((a, b) => b.localeCompare(a));
    return Promise.resolve(ok(joinedAts[0] ?? null));
  }

  public listByApartment(
    apartmentId: string,
  ): Promise<Result<readonly ApartmentMemberView[], DomainError>> {
    const views: ApartmentMemberView[] = Array.from(this.memberships.values())
      .filter((m) => m.apartmentId === apartmentId)
      .map((m) => {
        const profile = this.users.get(m.userId);
        return {
          userId: m.userId,
          displayName: profile?.displayName ?? m.userId,
          shortTag: profile?.shortTag ?? 'USR1',
          color: profile?.color ?? '#007AFF',
          role: m.role,
          joinedAt: m.joinedAt,
          leftAt: m.leftAt,
        };
      });
    return Promise.resolve(ok(views));
  }

  public joinAsContributor(params: JoinAsContributorParams): Promise<Result<void, DomainError>> {
    this.memberships.set(InMemoryMembershipRepository.key(params.apartmentId, params.userId), {
      apartmentId: params.apartmentId,
      userId: params.userId,
      role: MEMBERSHIP_ROLES.CONTRIBUTOR,
      joinedAt: params.joinedAt,
      leftAt: null,
    });
    this.changeLog.push({
      apartmentId: params.apartmentId,
      userId: params.userId,
      op: 'joined',
      createdAt: params.joinedAt,
    });
    return Promise.resolve(ok(undefined));
  }

  public markLeft(params: MarkMembershipLeftParams): Promise<Result<void, DomainError>> {
    const existing = this.memberships.get(
      InMemoryMembershipRepository.key(params.apartmentId, params.userId),
    );
    if (existing !== undefined && existing.leftAt === null) {
      this.memberships.set(InMemoryMembershipRepository.key(params.apartmentId, params.userId), {
        ...existing,
        leftAt: params.leftAt,
      });
      this.changeLog.push({
        apartmentId: params.apartmentId,
        userId: params.userId,
        op: params.op,
        createdAt: params.leftAt,
      });
    }
    return Promise.resolve(ok(undefined));
  }
}
