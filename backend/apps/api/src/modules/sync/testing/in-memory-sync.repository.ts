import { ok, type DomainError, type Result } from '@stanmieszkania/shared';
import { SYNC_ENTITY_TYPES, SYNC_ROLES } from '../domain/sync.constants';
import {
  projectApartmentSnapshotForCaller,
  projectEntrySnapshot,
  type HydratedSyncChange,
  type MyApartmentSyncSummary,
  type RawApartmentForSync,
  type SyncChangesPage,
  type SyncChangePayload,
  type SyncEntrySnapshot,
  type SyncMediaSnapshot,
  type SyncMemberSnapshot,
  type SyncRole,
} from '../domain/sync.entity';
import type {
  ListChangesAfterQuery,
  SyncApartmentAccess,
  SyncRepository,
} from '../domain/sync.repository';

interface StoredChange {
  readonly seq: number;
  readonly apartmentId: string;
  readonly entityType: string;
  readonly entityId: string;
  readonly op: string;
  readonly createdAt: string;
}

export class InMemorySyncRepository implements SyncRepository {
  private readonly apartments = new Map<string, RawApartmentForSync>();
  private readonly members = new Map<string, SyncMemberSnapshot[]>();
  private readonly media = new Map<string, SyncMediaSnapshot>();
  private readonly entries = new Map<string, SyncEntrySnapshot>();
  private readonly changes: StoredChange[] = [];
  private nextSeqCounter = 1;

  seedApartment(apartment: RawApartmentForSync): void {
    this.apartments.set(apartment.id, apartment);
  }

  seedMember(apartmentId: string, member: SyncMemberSnapshot): void {
    const list = this.members.get(apartmentId) ?? [];
    const filtered = list.filter((m) => m.userId !== member.userId);
    filtered.push(member);
    this.members.set(apartmentId, filtered);
  }

  seedMedia(item: SyncMediaSnapshot): void {
    this.media.set(item.id, item);
  }

  seedEntry(entry: SyncEntrySnapshot): void {
    this.entries.set(entry.id, entry);
  }

  appendChange(
    apartmentId: string,
    entityType: string,
    entityId: string,
    op: string,
    createdAt: string,
  ): number {
    const seq = this.nextSeqCounter;
    this.nextSeqCounter += 1;
    this.changes.push({ seq, apartmentId, entityType, entityId, op, createdAt });
    return seq;
  }

  private latestContributorJoinedAt(apartmentId: string): string | null {
    const joined = (this.members.get(apartmentId) ?? [])
      .filter((m) => m.role === SYNC_ROLES.CONTRIBUTOR && m.leftAt === null)
      .map((m) => m.joinedAt)
      .sort();
    return joined[joined.length - 1] ?? null;
  }

  findApartmentAccess(
    apartmentId: string,
    userId: string,
  ): Promise<Result<SyncApartmentAccess | null, DomainError>> {
    if (!this.apartments.has(apartmentId)) return Promise.resolve(ok(null));
    const active = (this.members.get(apartmentId) ?? []).find(
      (m) => m.userId === userId && m.leftAt === null,
    );
    return Promise.resolve(
      ok({
        apartmentId,
        role: active?.role ?? SYNC_ROLES.CONTRIBUTOR,
        isActiveMember: active !== undefined,
      }),
    );
  }

  listChangesAfter(query: ListChangesAfterQuery): Promise<Result<SyncChangesPage, DomainError>> {
    const matching = this.changes.filter(
      (c) => c.apartmentId === query.apartmentId && c.seq > query.afterSeq,
    );
    const hasMore = matching.length > query.limit;
    const slice = hasMore ? matching.slice(0, query.limit) : matching;
    const changes: HydratedSyncChange[] = slice.map((c) => ({
      ...c,
      payload: this.hydrate(c, query.callerRole),
    }));
    const last = changes[changes.length - 1];
    return Promise.resolve(ok({ changes, nextSeq: last?.seq ?? null, hasMore }));
  }

  private hydrate(change: StoredChange, callerRole: SyncRole): SyncChangePayload | null {
    if (change.entityType === SYNC_ENTITY_TYPES.APARTMENT) {
      const apt = this.apartments.get(change.apartmentId);
      if (apt === undefined) return null;
      return {
        kind: 'apartment',
        apartment: projectApartmentSnapshotForCaller(
          apt,
          callerRole,
          this.latestContributorJoinedAt(apt.id),
        ),
      };
    }
    if (change.entityType === SYNC_ENTITY_TYPES.MEMBERSHIP) {
      const member = (this.members.get(change.apartmentId) ?? []).find(
        (m) => m.userId === change.entityId,
      );
      return member !== undefined ? { kind: 'member', member } : null;
    }
    if (change.entityType === SYNC_ENTITY_TYPES.MEDIA) {
      const item = this.media.get(change.entityId);
      return item !== undefined ? { kind: 'media', media: item } : null;
    }
    if (change.entityType === SYNC_ENTITY_TYPES.ENTRY) {
      const entry = this.entries.get(change.entityId);
      return entry !== undefined ? { kind: 'entry', entry: projectEntrySnapshot(entry) } : null;
    }
    return null;
  }

  listMyApartmentsSync(
    userId: string,
  ): Promise<Result<readonly MyApartmentSyncSummary[], DomainError>> {
    const items: MyApartmentSyncSummary[] = [];
    for (const [apartmentId, apt] of this.apartments.entries()) {
      const member = (this.members.get(apartmentId) ?? []).find(
        (m) => m.userId === userId && m.leftAt === null,
      );
      if (member === undefined) continue;
      const headSeq = this.changes
        .filter((c) => c.apartmentId === apartmentId)
        .reduce((max, c) => Math.max(max, c.seq), 0);
      const confirmedMedia = Array.from(this.media.values()).filter(
        (m) =>
          m.apartmentId === apartmentId && m.uploadStatus === 'uploaded' && m.deletedAt === null,
      );
      const latestMediaCapturedAt =
        confirmedMedia
          .map((m) => m.capturedAt)
          .sort()
          .pop() ?? null;
      items.push({
        apartment: projectApartmentSnapshotForCaller(
          apt,
          member.role,
          this.latestContributorJoinedAt(apartmentId),
        ),
        role: member.role,
        headSeq,
        confirmedMediaCount: confirmedMedia.length,
        latestMediaCapturedAt,
      });
    }
    return Promise.resolve(ok(items));
  }
}
