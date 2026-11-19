import { ok } from '@stanmieszkania/shared';
import { REDACTED_ENTRY_TEXT } from '../domain/entries.constants';
import type { Entry } from '../domain/entry.entity';
import type {
  ApartmentEntryAccess,
  EntryAuthorSummary,
  EntryRepository,
  EntryTargetMediaAccess,
  EntryWithAuthor,
  InsertEntryWithMarkersParams,
  RetractEntryParams,
} from '../domain/entry.repository';
import type { Marker } from '../domain/marker.entity';

export class InMemoryEntryRepository implements EntryRepository {
  private readonly apartments = new Map<string, Set<string>>();
  private readonly mediaById = new Map<string, Omit<EntryTargetMediaAccess, 'isActiveMember'>>();
  private readonly authorsByUserId = new Map<string, EntryAuthorSummary>();
  private readonly entriesById = new Map<string, Entry>();
  private readonly markersByMediaId = new Map<string, Marker[]>();

  seedApartment(apartmentId: string, activeMemberIds: readonly string[]): void {
    this.apartments.set(apartmentId, new Set(activeMemberIds));
  }

  seedAuthor(author: EntryAuthorSummary): void {
    this.authorsByUserId.set(author.userId, author);
  }

  seedMedia(media: Omit<EntryTargetMediaAccess, 'isActiveMember'>): void {
    this.mediaById.set(media.mediaId, media);
  }

  findApartmentMembership(apartmentId: string, userId: string) {
    const members = this.apartments.get(apartmentId);
    if (members === undefined) {
      return Promise.resolve(ok<ApartmentEntryAccess | null>(null));
    }
    return Promise.resolve(ok({ apartmentId, isActiveMember: members.has(userId) }));
  }

  findTargetMediaAccess(mediaId: string, userId: string) {
    const media = this.mediaById.get(mediaId);
    if (media === undefined) {
      return Promise.resolve(ok<EntryTargetMediaAccess | null>(null));
    }
    const members = this.apartments.get(media.apartmentId);
    return Promise.resolve(
      ok({ ...media, isActiveMember: members !== undefined && members.has(userId) }),
    );
  }

  findById(entryId: string) {
    const entry = this.entriesById.get(entryId);
    return Promise.resolve(ok(entry === undefined ? null : this.maskRetracted(entry)));
  }

  findByIdWithAuthor(entryId: string) {
    const entry = this.entriesById.get(entryId);
    if (entry === undefined) {
      return Promise.resolve(ok<EntryWithAuthor | null>(null));
    }
    return Promise.resolve(
      ok({
        entry: this.maskRetracted(entry),
        author: this.resolveAuthor(entry.authorId),
      }),
    );
  }

  listByMedia(mediaId: string) {
    const items = [...this.entriesById.values()]
      .filter((entry) => entry.mediaId === mediaId)
      .sort((left, right) => {
        const createdCmp = left.createdAt.localeCompare(right.createdAt);
        return createdCmp !== 0 ? createdCmp : left.id.localeCompare(right.id);
      })
      .map((entry) => ({
        entry: this.maskRetracted(entry),
        author: this.resolveAuthor(entry.authorId),
      }));
    return Promise.resolve(ok(items));
  }

  getMaxMarkerNumber(mediaId: string) {
    const markers = this.markersByMediaId.get(mediaId) ?? [];
    const max = markers.reduce((highest, marker) => Math.max(highest, marker.number), 0);
    return Promise.resolve(ok(max));
  }

  insertWithMarkers({ entry }: InsertEntryWithMarkersParams) {
    this.entriesById.set(entry.id, entry);
    const existing = this.markersByMediaId.get(entry.mediaId) ?? [];
    this.markersByMediaId.set(entry.mediaId, [...existing, ...entry.markers]);
    return Promise.resolve(ok());
  }

  retract({ entryId, retractedAt }: RetractEntryParams) {
    const existing = this.entriesById.get(entryId);
    if (existing !== undefined && existing.retractedAt === null) {
      this.entriesById.set(entryId, {
        ...existing,
        text: REDACTED_ENTRY_TEXT,
        retractedAt,
      });
    }
    return Promise.resolve(ok());
  }

  private maskRetracted(entry: Entry): Entry {
    if (entry.retractedAt === null) {
      return entry;
    }
    return {
      ...entry,
      text: REDACTED_ENTRY_TEXT,
      markers: [],
    };
  }

  private resolveAuthor(userId: string): EntryAuthorSummary {
    return (
      this.authorsByUserId.get(userId) ?? {
        userId,
        displayName: userId,
        shortTag: 'TEST',
        color: '#3B82F6',
        role: 'contributor',
      }
    );
  }
}
