import { createDomainError, err, ok, type DomainError, type Result } from '@stanmieszkania/shared';
import type { ApartmentChange } from '../domain/apartment-change.entity';
import type { Apartment } from '../domain/apartment.entity';
import type {
  ApartmentListEntry,
  ApartmentMemberRole,
  ApartmentRepository,
} from '../domain/apartment.repository';
import type { ActiveContributor } from '../domain/ownership-transfer.policy';

interface StoredMembership {
  readonly apartmentId: string;
  readonly userId: string;
  role: ApartmentMemberRole;
  readonly joinedAt: string;
  leftAt: string | null;
}

export class InMemoryApartmentRepository implements ApartmentRepository {
  private readonly apartments = new Map<string, Apartment>();
  private readonly memberships: StoredMembership[] = [];
  private readonly changes: ApartmentChange[] = [];

  seedMembership(params: {
    readonly apartmentId: string;
    readonly userId: string;
    readonly role: ApartmentMemberRole;
    readonly joinedAt: string;
    readonly leftAt?: string | null;
  }): void {
    this.memberships.push({
      apartmentId: params.apartmentId,
      userId: params.userId,
      role: params.role,
      joinedAt: params.joinedAt,
      leftAt: params.leftAt ?? null,
    });
  }

  getAll(): readonly Apartment[] {
    return Array.from(this.apartments.values());
  }

  findById(id: string): Promise<Result<Apartment | null, DomainError>> {
    const found = this.apartments.get(id);
    if (found === undefined || found.deletedAt !== null) {
      return Promise.resolve(ok(null));
    }
    return Promise.resolve(ok(found));
  }

  findByInviteCode(inviteCode: string): Promise<Result<Apartment | null, DomainError>> {
    for (const apartment of this.apartments.values()) {
      if (apartment.deletedAt === null && apartment.inviteCode === inviteCode) {
        return Promise.resolve(ok(apartment));
      }
    }
    return Promise.resolve(ok(null));
  }

  findActiveRole(
    apartmentId: string,
    userId: string,
  ): Promise<Result<ApartmentMemberRole | null, DomainError>> {
    const member = this.memberships.find(
      (m) => m.apartmentId === apartmentId && m.userId === userId && m.leftAt === null,
    );
    return Promise.resolve(ok(member?.role ?? null));
  }

  getLatestContributorJoinedAt(apartmentId: string): Promise<Result<string | null, DomainError>> {
    const contributors = this.memberships
      .filter((m) => m.apartmentId === apartmentId && m.role === 'contributor' && m.leftAt === null)
      .map((m) => m.joinedAt)
      .sort();
    const latest = contributors[contributors.length - 1] ?? null;
    return Promise.resolve(ok(latest));
  }

  listActiveContributors(
    apartmentId: string,
  ): Promise<Result<readonly ActiveContributor[], DomainError>> {
    const contributors = this.memberships
      .filter((m) => m.apartmentId === apartmentId && m.role === 'contributor' && m.leftAt === null)
      .map((m) => ({ userId: m.userId, joinedAt: m.joinedAt }));
    return Promise.resolve(ok(contributors));
  }

  async listForUser(userId: string): Promise<Result<readonly ApartmentListEntry[], DomainError>> {
    const entries: ApartmentListEntry[] = [];
    for (const m of this.memberships) {
      if (m.userId !== userId || m.leftAt !== null) {
        continue;
      }
      const apartment = this.apartments.get(m.apartmentId);
      if (apartment === undefined || apartment.deletedAt !== null) {
        continue;
      }
      const latest = await this.getLatestContributorJoinedAt(apartment.id);
      if (!latest.ok) {
        return latest;
      }
      entries.push({
        apartment,
        role: m.role,
        latestContributorJoinedAt: latest.value,
      });
    }
    return ok(entries);
  }

  createWithOwnerMembership(params: {
    readonly apartment: Apartment;
    readonly joinedAt: string;
  }): Promise<Result<void, DomainError>> {
    if (this.apartments.has(params.apartment.id)) {
      return Promise.resolve(err(createDomainError('DB_BATCH_FAILED', 'Duplicate apartment id')));
    }
    for (const existing of this.apartments.values()) {
      if (existing.inviteCode === params.apartment.inviteCode) {
        return Promise.resolve(err(createDomainError('DB_BATCH_FAILED', 'Duplicate invite_code')));
      }
    }
    this.apartments.set(params.apartment.id, params.apartment);
    this.memberships.push({
      apartmentId: params.apartment.id,
      userId: params.apartment.ownerId,
      role: 'owner',
      joinedAt: params.joinedAt,
      leftAt: null,
    });
    return Promise.resolve(ok(undefined));
  }

  updateWithChanges(params: {
    readonly apartment: Apartment;
    readonly changes: readonly ApartmentChange[];
  }): Promise<Result<void, DomainError>> {
    this.apartments.set(params.apartment.id, params.apartment);
    this.changes.push(...params.changes);
    return Promise.resolve(ok(undefined));
  }

  rotateInviteCode(params: {
    readonly apartmentId: string;
    readonly inviteCode: string;
    readonly rotatedAt: string;
  }): Promise<Result<void, DomainError>> {
    const existing = this.apartments.get(params.apartmentId);
    if (existing !== undefined) {
      this.apartments.set(params.apartmentId, {
        ...existing,
        inviteCode: params.inviteCode,
        inviteCodeRotatedAt: params.rotatedAt,
        updatedAt: params.rotatedAt,
      });
    }
    return Promise.resolve(ok(undefined));
  }

  transferOwnershipAndLeave(params: {
    readonly apartmentId: string;
    readonly previousOwnerId: string;
    readonly newOwnerId: string;
    readonly leftAt: string;
  }): Promise<Result<void, DomainError>> {
    const existing = this.apartments.get(params.apartmentId);
    if (existing !== undefined) {
      this.apartments.set(params.apartmentId, {
        ...existing,
        ownerId: params.newOwnerId,
        updatedAt: params.leftAt,
      });
    }
    for (const m of this.memberships) {
      if (m.apartmentId === params.apartmentId && m.userId === params.previousOwnerId) {
        m.leftAt = params.leftAt;
      }
      if (m.apartmentId === params.apartmentId && m.userId === params.newOwnerId) {
        m.role = 'owner';
      }
    }
    return Promise.resolve(ok(undefined));
  }

  leaveAsContributor(params: {
    readonly apartmentId: string;
    readonly userId: string;
    readonly leftAt: string;
  }): Promise<Result<void, DomainError>> {
    for (const m of this.memberships) {
      if (m.apartmentId === params.apartmentId && m.userId === params.userId && m.leftAt === null) {
        m.leftAt = params.leftAt;
      }
    }
    return Promise.resolve(ok(undefined));
  }

  hardDelete(apartmentId: string): Promise<Result<void, DomainError>> {
    this.apartments.delete(apartmentId);
    return Promise.resolve(ok(undefined));
  }

  listChanges(apartmentId: string): Promise<Result<readonly ApartmentChange[], DomainError>> {
    return Promise.resolve(ok(this.changes.filter((c) => c.apartmentId === apartmentId)));
  }
}
