import { REDACTED_ENTRY_TEXT } from '../domain/entries.constants';
import type { Entry } from '../domain/entry.entity';
import type { EntryWithAuthor } from '../domain/entry.repository';
import type { Marker } from '../domain/marker.entity';
import type { EntryRow } from './entries.table';
import type { MarkerRow } from './markers.table';

export interface EntryWithAuthorRow extends EntryRow {
  readonly author_display_name: string;
  readonly author_short_tag: string;
  readonly author_color: string;
  readonly author_role: 'owner' | 'contributor' | null;
}

export function mapMarkerRowToEntity(row: MarkerRow): Marker {
  return {
    id: row.id,
    entryId: row.entry_id,
    mediaId: row.media_id,
    number: row.number,
    x: row.x,
    y: row.y,
  };
}

export function mapMarkerEntityToRow(marker: Marker): MarkerRow {
  return {
    id: marker.id,
    entry_id: marker.entryId,
    media_id: marker.mediaId,
    number: marker.number,
    x: marker.x,
    y: marker.y,
  };
}

// Decision S2-3: Mask retracted entry text and markers on read while SQLite markers remain for monotonic MAX(number).
export function mapEntryRowToEntity(row: EntryRow, markers: readonly Marker[]): Entry {
  const isRetracted = row.retracted_at !== null;
  return {
    id: row.id,
    mediaId: row.media_id,
    authorId: row.author_id,
    text: isRetracted ? REDACTED_ENTRY_TEXT : row.text,
    markers: isRetracted ? [] : markers,
    createdAt: row.created_at,
    serverReceivedAt: row.server_received_at,
    retractedAt: row.retracted_at,
  };
}

export function mapEntryEntityToRow(entry: Entry): EntryRow {
  return {
    id: entry.id,
    media_id: entry.mediaId,
    author_id: entry.authorId,
    text: entry.text,
    created_at: entry.createdAt,
    server_received_at: entry.serverReceivedAt,
    retracted_at: entry.retractedAt,
  };
}

export function mapEntryWithAuthorRowToEntity(
  row: EntryWithAuthorRow,
  markers: readonly Marker[],
): EntryWithAuthor {
  return {
    entry: mapEntryRowToEntity(row, markers),
    author: {
      userId: row.author_id,
      displayName: row.author_display_name,
      shortTag: row.author_short_tag,
      color: row.author_color,
      role: row.author_role ?? 'contributor',
    },
  };
}
