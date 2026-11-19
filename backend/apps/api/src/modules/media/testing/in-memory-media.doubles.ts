import { err, ok, type CursorPage, type DomainError, type Result } from '@stanmieszkania/shared';
import type { Media } from '../domain/media.entity';
import { quotaExceededError } from '../domain/media.errors';
import type {
  ApartmentMediaAccess,
  ConfirmMediaUploadedParams,
  MediaAuthorSummary,
  MediaListQuery,
  MediaRepository,
  MediaWithAuthor,
  ReservePendingMediaParams,
  SoftDeleteMediaParams,
} from '../domain/media.repository';
import type {
  CreatePresignedGetUrlParams,
  CreatePresignedPutUrlParams,
  ObjectStoragePort,
  PresignedUrl,
  UploadedObjectMetadata,
} from '../domain/object-storage.port';

export class InMemoryMediaRepository implements MediaRepository {
  private readonly apartments = new Map<string, { cloudMediaCount: number }>();
  private readonly members = new Map<string, Set<string>>();
  private readonly authors = new Map<string, MediaAuthorSummary>();
  private readonly items = new Map<string, Media>();

  seedApartment(apartmentId: string, cloudMediaCount = 0): void {
    this.apartments.set(apartmentId, { cloudMediaCount });
  }

  seedMember(apartmentId: string, author: MediaAuthorSummary): void {
    const set = this.members.get(apartmentId) ?? new Set<string>();
    set.add(author.userId);
    this.members.set(apartmentId, set);
    this.authors.set(author.userId, author);
  }

  getCloudMediaCount(apartmentId: string): number {
    return this.apartments.get(apartmentId)?.cloudMediaCount ?? 0;
  }

  findApartmentAccess(
    apartmentId: string,
    userId: string,
  ): Promise<Result<ApartmentMediaAccess | null, DomainError>> {
    const apt = this.apartments.get(apartmentId);
    if (apt === undefined) return Promise.resolve(ok(null));
    const isActiveMember = this.members.get(apartmentId)?.has(userId) ?? false;
    return Promise.resolve(
      ok({ apartmentId, cloudMediaCount: apt.cloudMediaCount, isActiveMember }),
    );
  }

  findById(mediaId: string): Promise<Result<Media | null, DomainError>> {
    return Promise.resolve(ok(this.items.get(mediaId) ?? null));
  }

  findByIdWithAuthor(mediaId: string): Promise<Result<MediaWithAuthor | null, DomainError>> {
    const media = this.items.get(mediaId);
    if (media === undefined) return Promise.resolve(ok(null));
    const author = this.authors.get(media.authorId) ?? {
      userId: media.authorId,
      displayName: media.authorId,
      shortTag: 'USR1',
      color: '#007AFF',
      role: 'contributor' as const,
    };
    return Promise.resolve(ok({ media, author }));
  }

  listByApartment(
    query: MediaListQuery,
  ): Promise<Result<CursorPage<MediaWithAuthor, string>, DomainError>> {
    const sorted = Array.from(this.items.values())
      .filter(
        (m) =>
          m.apartmentId === query.apartmentId &&
          (m.uploadStatus === 'uploaded' || m.authorId === query.viewerUserId),
      )
      .sort((a, b) => b.capturedAt.localeCompare(a.capturedAt) || b.id.localeCompare(a.id));
    const slice = sorted.slice(0, query.limit);
    const items = slice.map((media) => ({
      media,
      author: this.authors.get(media.authorId) ?? {
        userId: media.authorId,
        displayName: media.authorId,
        shortTag: 'USR1',
        color: '#007AFF',
        role: 'contributor' as const,
      },
    }));
    const last = items[items.length - 1];
    const hasMore = sorted.length > query.limit;
    return Promise.resolve(
      ok({
        items,
        hasMore,
        nextCursor:
          hasMore && last !== undefined ? `${last.media.capturedAt}|${last.media.id}` : null,
      }),
    );
  }

  reservePendingSlot(params: ReservePendingMediaParams): Promise<Result<void, DomainError>> {
    const apt = this.apartments.get(params.media.apartmentId);
    if (apt === undefined || apt.cloudMediaCount >= params.quota) {
      return Promise.resolve(err(quotaExceededError(apt?.cloudMediaCount ?? 0, params.quota)));
    }
    apt.cloudMediaCount += 1;
    this.items.set(params.media.id, params.media);
    return Promise.resolve(ok(undefined));
  }

  markUploaded(params: ConfirmMediaUploadedParams): Promise<Result<void, DomainError>> {
    const existing = this.items.get(params.mediaId);
    if (existing !== undefined) {
      this.items.set(params.mediaId, {
        ...existing,
        uploadStatus: 'uploaded',
        serverReceivedAt: params.serverReceivedAt,
      });
    }
    return Promise.resolve(ok(undefined));
  }

  softDelete(params: SoftDeleteMediaParams): Promise<Result<void, DomainError>> {
    const existing = this.items.get(params.mediaId);
    if (existing !== undefined) {
      this.items.set(params.mediaId, {
        ...existing,
        deletedAt: params.deletedAt,
        deletedBy: params.deletedBy,
      });
    }
    return Promise.resolve(ok(undefined));
  }
}

export class InMemoryObjectStorage implements ObjectStoragePort {
  public readonly objects = new Map<string, { readonly bytes: number; readonly sha256: string }>();

  seedObject(r2Key: string, bytes: number, sha256: string): void {
    this.objects.set(r2Key, { bytes, sha256 });
  }

  createPresignedPutUrl(
    params: CreatePresignedPutUrlParams,
  ): Promise<Result<PresignedUrl, DomainError>> {
    return Promise.resolve(
      ok({
        url: `https://local.test/put?key=${encodeURIComponent(params.r2Key)}`,
        expiresAt: new Date(Date.now() + params.expiresInMs).toISOString(),
      }),
    );
  }

  createPresignedGetUrl(
    params: CreatePresignedGetUrlParams,
  ): Promise<Result<PresignedUrl, DomainError>> {
    return Promise.resolve(
      ok({
        url: `https://local.test/get?key=${encodeURIComponent(params.r2Key)}`,
        expiresAt: new Date(Date.now() + params.expiresInMs).toISOString(),
      }),
    );
  }

  headObject(r2Key: string): Promise<Result<UploadedObjectMetadata | null, DomainError>> {
    const obj = this.objects.get(r2Key);
    return Promise.resolve(
      ok(obj === undefined ? null : { bytes: obj.bytes, sha256: obj.sha256, etag: 'mem-etag' }),
    );
  }

  readObjectSha256(r2Key: string): Promise<Result<string | null, DomainError>> {
    return Promise.resolve(ok(this.objects.get(r2Key)?.sha256 ?? null));
  }

  deleteObject(r2Key: string): Promise<Result<void, DomainError>> {
    this.objects.delete(r2Key);
    return Promise.resolve(ok(undefined));
  }
}
