import type { DomainError, Result } from '@stanmieszkania/shared';
import type { Entry, TargetMediaReadiness } from './entry.entity';

export interface EntryTargetMediaAccess extends TargetMediaReadiness {
  readonly apartmentId: string;
  readonly isActiveMember: boolean;
}

export interface EntryAuthorSummary {
  readonly userId: string;
  readonly displayName: string;
  readonly shortTag: string;
  readonly color: string;
  readonly role: 'owner' | 'contributor';
}

export interface EntryWithAuthor {
  readonly entry: Entry;
  readonly author: EntryAuthorSummary;
}

export interface InsertEntryWithMarkersParams {
  readonly apartmentId: string;
  readonly entry: Entry;
}

export interface RetractEntryParams {
  readonly entryId: string;
  readonly apartmentId: string;
  readonly retractedAt: string;
}

export interface EntryRepository {
  findTargetMediaAccess(
    mediaId: string,
    userId: string,
  ): Promise<Result<EntryTargetMediaAccess | null, DomainError>>;
  findById(entryId: string): Promise<Result<Entry | null, DomainError>>;
  findByIdWithAuthor(entryId: string): Promise<Result<EntryWithAuthor | null, DomainError>>;
  listByMedia(mediaId: string): Promise<Result<readonly EntryWithAuthor[], DomainError>>;
  getMaxMarkerNumber(mediaId: string): Promise<Result<number, DomainError>>;
  insertWithMarkers(params: InsertEntryWithMarkersParams): Promise<Result<void, DomainError>>;
  retract(params: RetractEntryParams): Promise<Result<void, DomainError>>;
}
