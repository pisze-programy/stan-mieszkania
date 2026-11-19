import type { MarkerRow } from '../../entries';
import { SYNC_ENTITY_TYPES, SYNC_ROLES } from '../domain/sync.constants';
import {
  projectApartmentSnapshotForCaller,
  projectEntrySnapshot,
  type HydratedSyncChange,
  type MyApartmentSyncSummary,
  type SyncApartmentSnapshot,
  type SyncChangePayload,
  type SyncEntrySnapshot,
  type SyncMarkerSnapshot,
  type SyncMediaSnapshot,
  type SyncMemberSnapshot,
  type SyncRole,
} from '../domain/sync.entity';
import type { ChangeLogRow } from './change-log.table';
import type {
  MyApartmentSyncRow,
  SyncApartmentHydrationRow,
  SyncEntryHydrationRow,
  SyncMediaHydrationRow,
  SyncMemberHydrationRow,
} from './sync.queries';

const IMPORT_FLAG_TRUE = 1;

export interface HydrationMaps {
  readonly apartment: SyncApartmentSnapshot | null;
  readonly members: ReadonlyMap<string, SyncMemberSnapshot>;
  readonly media: ReadonlyMap<string, SyncMediaSnapshot>;
  readonly entries: ReadonlyMap<string, SyncEntrySnapshot>;
}

export function mapApartmentHydrationRow(
  row: SyncApartmentHydrationRow,
  callerRole: SyncRole,
): SyncApartmentSnapshot {
  return projectApartmentSnapshotForCaller(
    {
      id: row.id,
      ownerId: row.owner_id,
      name: row.name,
      street: row.street,
      city: row.city,
      inviteCode: row.invite_code,
      inviteCodeRotatedAt: row.invite_code_rotated_at,
      cloudMediaCount: row.cloud_media_count,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    },
    callerRole,
    row.latest_contributor_joined_at,
  );
}

export function mapMemberHydrationRow(row: SyncMemberHydrationRow): SyncMemberSnapshot {
  return {
    userId: row.user_id,
    displayName: row.display_name,
    shortTag: row.short_tag,
    color: row.color,
    role: row.role,
    joinedAt: row.joined_at,
    leftAt: row.left_at,
  };
}

export function mapMediaHydrationRow(row: SyncMediaHydrationRow): SyncMediaSnapshot {
  return {
    id: row.id,
    apartmentId: row.apartment_id,
    authorId: row.author_id,
    kind: row.kind,
    source: row.source,
    uploadStatus: row.upload_status === 'confirmed' ? 'uploaded' : 'pending',
    sha256: row.sha256,
    capturedAt: row.captured_at,
    capturedTz: row.captured_tz,
    capturedAtFromImport: row.captured_at_from_import === IMPORT_FLAG_TRUE,
    serverReceivedAt: row.server_received_at,
    width: row.width,
    height: row.height,
    bytes: row.bytes,
    deletedAt: row.deleted_at,
    deletedBy: row.deleted_by,
    author: {
      userId: row.author_id,
      displayName: row.author_display_name,
      shortTag: row.author_short_tag,
      color: row.author_color,
      role: row.author_role ?? SYNC_ROLES.CONTRIBUTOR,
    },
  };
}

export function mapMarkerRowToSyncSnapshot(row: MarkerRow): SyncMarkerSnapshot {
  return {
    id: row.id,
    entryId: row.entry_id,
    mediaId: row.media_id,
    number: row.number,
    x: row.x,
    y: row.y,
  };
}

export function mapEntryHydrationRow(
  row: SyncEntryHydrationRow,
  markers: readonly SyncMarkerSnapshot[],
): SyncEntrySnapshot {
  return projectEntrySnapshot({
    id: row.id,
    mediaId: row.media_id,
    authorId: row.author_id,
    text: row.text,
    markers,
    createdAt: row.created_at,
    serverReceivedAt: row.server_received_at,
    retractedAt: row.retracted_at,
    author: {
      userId: row.author_id,
      displayName: row.author_display_name,
      shortTag: row.author_short_tag,
      color: row.author_color,
      role: row.author_role ?? SYNC_ROLES.CONTRIBUTOR,
    },
  });
}

export function resolveChangePayload(
  row: ChangeLogRow,
  maps: HydrationMaps,
): SyncChangePayload | null {
  switch (row.entity_type) {
    case SYNC_ENTITY_TYPES.APARTMENT:
      return maps.apartment !== null ? { kind: 'apartment', apartment: maps.apartment } : null;
    case SYNC_ENTITY_TYPES.MEMBERSHIP: {
      const member = maps.members.get(row.entity_id);
      return member !== undefined ? { kind: 'member', member } : null;
    }
    case SYNC_ENTITY_TYPES.MEDIA: {
      const media = maps.media.get(row.entity_id);
      return media !== undefined ? { kind: 'media', media } : null;
    }
    case SYNC_ENTITY_TYPES.ENTRY: {
      const entry = maps.entries.get(row.entity_id);
      return entry !== undefined ? { kind: 'entry', entry } : null;
    }
    default:
      return null;
  }
}

export function mapHydratedChange(row: ChangeLogRow, maps: HydrationMaps): HydratedSyncChange {
  return {
    seq: row.seq,
    apartmentId: row.apartment_id,
    entityType: row.entity_type,
    entityId: row.entity_id,
    op: row.op,
    createdAt: row.created_at,
    payload: resolveChangePayload(row, maps),
  };
}

export function mapMyApartmentSyncRow(row: MyApartmentSyncRow): MyApartmentSyncSummary {
  return {
    apartment: mapApartmentHydrationRow(row, row.member_role),
    role: row.member_role,
    headSeq: row.head_seq,
    confirmedMediaCount: row.confirmed_media_count,
    latestMediaCapturedAt: row.latest_media_captured_at,
  };
}
