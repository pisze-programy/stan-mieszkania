import { SYNC_ROLES } from './sync.constants';

export type SyncRole = 'owner' | 'contributor';

export interface SyncActorSummary {
  readonly userId: string;
  readonly displayName: string;
  readonly shortTag: string;
  readonly color: string;
  readonly role: SyncRole;
}

export interface SyncApartmentSnapshot {
  readonly id: string;
  readonly ownerId: string;
  readonly name: string;
  readonly street: string;
  readonly city: string;
  readonly role: SyncRole;
  readonly inviteCode: string | null;
  readonly shouldSuggestInviteCodeReset: boolean;
  readonly cloudMediaCount: number;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export interface SyncMemberSnapshot {
  readonly userId: string;
  readonly displayName: string;
  readonly shortTag: string;
  readonly color: string;
  readonly role: SyncRole;
  readonly joinedAt: string;
  readonly leftAt: string | null;
}

// Decision Q10: SyncMediaSnapshot never carries GPS fields (lat, lng, accuracyM, locationSource).
export interface SyncMediaSnapshot {
  readonly id: string;
  readonly apartmentId: string;
  readonly authorId: string;
  readonly kind: 'photo' | 'video';
  readonly source: 'camera' | 'import';
  readonly uploadStatus: 'pending' | 'uploaded';
  readonly sha256: string;
  readonly capturedAt: string;
  readonly capturedTz: string;
  readonly capturedAtFromImport: boolean;
  readonly serverReceivedAt: string | null;
  readonly width: number;
  readonly height: number;
  readonly bytes: number;
  readonly deletedAt: string | null;
  readonly deletedBy: string | null;
  readonly author: SyncActorSummary;
}

export interface SyncMarkerSnapshot {
  readonly id: string;
  readonly entryId: string;
  readonly mediaId: string;
  readonly number: number;
  readonly x: number;
  readonly y: number;
}

export interface SyncEntrySnapshot {
  readonly id: string;
  readonly mediaId: string;
  readonly authorId: string;
  readonly text: string;
  readonly markers: readonly SyncMarkerSnapshot[];
  readonly createdAt: string;
  readonly serverReceivedAt: string;
  readonly retractedAt: string | null;
  readonly author: SyncActorSummary;
}

export type SyncChangePayload =
  | { readonly kind: 'apartment'; readonly apartment: SyncApartmentSnapshot }
  | { readonly kind: 'member'; readonly member: SyncMemberSnapshot }
  | { readonly kind: 'media'; readonly media: SyncMediaSnapshot }
  | { readonly kind: 'entry'; readonly entry: SyncEntrySnapshot };

export interface HydratedSyncChange {
  readonly seq: number;
  readonly apartmentId: string;
  readonly entityType: string;
  readonly entityId: string;
  readonly op: string;
  readonly createdAt: string;
  readonly payload: SyncChangePayload | null;
}

export interface SyncChangesPage {
  readonly changes: readonly HydratedSyncChange[];
  readonly nextSeq: number | null;
  readonly hasMore: boolean;
}

export interface MyApartmentSyncSummary {
  readonly apartment: SyncApartmentSnapshot;
  readonly role: SyncRole;
  readonly headSeq: number;
  readonly confirmedMediaCount: number;
  readonly latestMediaCapturedAt: string | null;
}

export interface RawApartmentForSync {
  readonly id: string;
  readonly ownerId: string;
  readonly name: string;
  readonly street: string;
  readonly city: string;
  readonly inviteCode: string;
  readonly inviteCodeRotatedAt: string | null;
  readonly cloudMediaCount: number;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export function shouldSuggestResetForSync(
  inviteCodeRotatedAt: string | null,
  latestContributorJoinedAt: string | null,
): boolean {
  if (latestContributorJoinedAt === null) return false;
  if (inviteCodeRotatedAt === null) return true;
  return Date.parse(latestContributorJoinedAt) > Date.parse(inviteCodeRotatedAt);
}

// Decision Q4/Q8/Q9: Invite code and reset prompt are exposed to owners only.
export function projectApartmentSnapshotForCaller(
  apartment: RawApartmentForSync,
  callerRole: SyncRole,
  latestContributorJoinedAt: string | null,
): SyncApartmentSnapshot {
  const isOwner = callerRole === SYNC_ROLES.OWNER;
  return {
    id: apartment.id,
    ownerId: apartment.ownerId,
    name: apartment.name,
    street: apartment.street,
    city: apartment.city,
    role: callerRole,
    inviteCode: isOwner ? apartment.inviteCode : null,
    shouldSuggestInviteCodeReset: isOwner
      ? shouldSuggestResetForSync(apartment.inviteCodeRotatedAt, latestContributorJoinedAt)
      : false,
    cloudMediaCount: apartment.cloudMediaCount,
    createdAt: apartment.createdAt,
    updatedAt: apartment.updatedAt,
  };
}

// Decision S2-3: Retracted entries always mask text and markers in sync payloads.
export function projectEntrySnapshot(entry: SyncEntrySnapshot): SyncEntrySnapshot {
  if (entry.retractedAt === null) {
    return entry;
  }
  return {
    ...entry,
    text: '',
    markers: [],
  };
}
