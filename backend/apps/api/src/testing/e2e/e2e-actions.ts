import { HTTP_STATUS } from '@stanmieszkania/http-contracts';
import { ApartmentDtoSchema, type ApartmentDto } from '../../modules/apartments';
import { EntryDtoSchema, type EntryDto } from '../../modules/entries';
import {
  InitMediaUploadResponseSchema,
  MEDIA_CONTENT_TYPE_JPEG,
  MediaDtoSchema,
  type InitMediaUploadResponseDto,
  type MediaDto,
} from '../../modules/media';
import { SyncChangesResponseSchema, type SyncChangesResponseDto } from '../../modules/sync';
import { sha256Hex, type E2eClient } from './e2e-client';

const DEFAULT_WIDTH_PX = 1200;
const DEFAULT_HEIGHT_PX = 900;
const MAX_SYNC_PAGES = 50;

export interface UploadPhotoInput {
  readonly token: string;
  readonly apartmentId: string;
  readonly mediaId: string;
  readonly bytes: Uint8Array<ArrayBuffer>;
  readonly capturedAt: string;
  readonly capturedTz?: string;
  readonly gps?: {
    readonly lat: number;
    readonly lng: number;
    readonly accuracyM: number;
    readonly locationSource: 'device' | 'exif';
  };
}

export interface UploadPhotoResult {
  readonly initDto: InitMediaUploadResponseDto;
  readonly mediaDto: MediaDto;
  readonly sha256: string;
}

export interface ExhaustedSyncFeed {
  readonly changes: SyncChangesResponseDto['changes'];
  readonly lastSeq: number;
  readonly pageCount: number;
}

export interface PutEntryInput {
  readonly token: string;
  readonly apartmentId: string;
  readonly mediaId: string;
  readonly entryId: string;
  readonly text: string;
  readonly createdAt: string;
  readonly markers?: readonly {
    readonly id: string;
    readonly localNumber: number;
    readonly x: number;
    readonly y: number;
  }[];
}

export async function jsonOf(
  client: E2eClient,
  path: string,
  token: string,
  method = 'GET',
  json?: unknown,
): Promise<unknown> {
  const res = await client.request(path, {
    method,
    token,
    ...(json !== undefined ? { json } : {}),
  });
  return res.json();
}

export async function putApartment(
  client: E2eClient,
  token: string,
  apartmentId: string,
  body: { readonly name: string; readonly street: string; readonly city: string },
): Promise<ApartmentDto> {
  const res = await client.request(`/v1/apartments/${apartmentId}`, {
    method: 'PUT',
    token,
    json: body,
  });
  if (res.status !== HTTP_STATUS.OK) {
    throw new Error(`Expected 200 on PUT apartment, got ${String(res.status)}`);
  }
  return ApartmentDtoSchema.parse(await res.json());
}

export async function putEntry(client: E2eClient, input: PutEntryInput): Promise<EntryDto> {
  const res = await client.request(
    `/v1/apartments/${input.apartmentId}/media/${input.mediaId}/entries/${input.entryId}`,
    {
      method: 'PUT',
      token: input.token,
      json: {
        text: input.text,
        createdAt: input.createdAt,
        markers: input.markers ?? [],
      },
    },
  );
  if (res.status !== HTTP_STATUS.OK) {
    throw new Error(`Expected 200 on PUT entry, got ${String(res.status)}`);
  }
  return EntryDtoSchema.parse(await res.json());
}

export async function uploadPhoto(
  client: E2eClient,
  input: UploadPhotoInput,
): Promise<UploadPhotoResult> {
  const sha256 = await sha256Hex(input.bytes);
  const initRes = await client.request(
    `/v1/apartments/${input.apartmentId}/media/${input.mediaId}/init`,
    {
      method: 'POST',
      token: input.token,
      json: {
        kind: 'photo',
        source: 'camera',
        sha256,
        capturedAt: input.capturedAt,
        capturedTz: input.capturedTz ?? 'Europe/Warsaw',
        width: DEFAULT_WIDTH_PX,
        height: DEFAULT_HEIGHT_PX,
        bytes: input.bytes.byteLength,
        ...(input.gps !== undefined ? input.gps : {}),
      },
    },
  );
  if (initRes.status !== HTTP_STATUS.OK) {
    throw new Error(`Expected 200 on media init, got ${String(initRes.status)}`);
  }
  const initDto = InitMediaUploadResponseSchema.parse(await initRes.json());
  if (initDto.upload === null) {
    throw new Error('Expected signed upload URL on fresh pending media init');
  }

  const putRes = await client.request(initDto.upload.url, {
    method: 'PUT',
    body: input.bytes,
    contentType: MEDIA_CONTENT_TYPE_JPEG,
  });
  if (putRes.status !== HTTP_STATUS.OK) {
    throw new Error(`Expected 200 on local storage PUT, got ${String(putRes.status)}`);
  }

  const confirmRes = await client.request(
    `/v1/apartments/${input.apartmentId}/media/${input.mediaId}/confirm`,
    { method: 'POST', token: input.token },
  );
  if (confirmRes.status !== HTTP_STATUS.OK) {
    throw new Error(`Expected 200 on media confirm, got ${String(confirmRes.status)}`);
  }
  return { initDto, mediaDto: MediaDtoSchema.parse(await confirmRes.json()), sha256 };
}

export async function exhaustCursorPages(
  client: E2eClient,
  token: string,
  apartmentId: string,
  startAfterSeq: number,
  limit: number,
): Promise<ExhaustedSyncFeed> {
  const allChanges: SyncChangesResponseDto['changes'] = [];
  let cursor = startAfterSeq;
  let pageCount = 0;

  for (let page = 0; page < MAX_SYNC_PAGES; page += 1) {
    const res = await client.request(
      `/v1/apartments/${apartmentId}/changes?after=${String(cursor)}&limit=${String(limit)}`,
      { token },
    );
    if (res.status !== HTTP_STATUS.OK) {
      throw new Error(`Expected 200 on sync changes, got ${String(res.status)}`);
    }
    const parsed = SyncChangesResponseSchema.parse(await res.json());
    pageCount += 1;
    allChanges.push(...parsed.changes);
    if (parsed.nextSeq !== null) {
      cursor = parsed.nextSeq;
    }
    if (!parsed.hasMore) {
      return { changes: allChanges, lastSeq: cursor, pageCount };
    }
  }
  throw new Error('Exceeded MAX_SYNC_PAGES while exhausting sync cursor pages');
}
