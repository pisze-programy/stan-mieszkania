import type { CursorPage, DomainError, Result } from '@stanmieszkania/shared';
import type { Media } from './media.entity';

export interface ApartmentMediaAccess {
  readonly apartmentId: string;
  readonly cloudMediaCount: number;
  readonly isActiveMember: boolean;
}

export interface MediaAuthorSummary {
  readonly userId: string;
  readonly displayName: string;
  readonly shortTag: string;
  readonly color: string;
  readonly role: 'owner' | 'contributor';
}

export interface MediaWithAuthor {
  readonly media: Media;
  readonly author: MediaAuthorSummary;
}

export interface MediaListQuery {
  readonly apartmentId: string;
  readonly viewerUserId: string;
  readonly after?: string;
  readonly limit: number;
}

export interface ReservePendingMediaParams {
  readonly media: Media;
  readonly quota: number;
  readonly createdAt: string;
}

export interface ConfirmMediaUploadedParams {
  readonly mediaId: string;
  readonly apartmentId: string;
  readonly serverReceivedAt: string;
}

export interface SoftDeleteMediaParams {
  readonly mediaId: string;
  readonly apartmentId: string;
  readonly deletedBy: string;
  readonly deletedAt: string;
}

export interface MediaRepository {
  findApartmentAccess(
    apartmentId: string,
    userId: string,
  ): Promise<Result<ApartmentMediaAccess | null, DomainError>>;
  findById(mediaId: string): Promise<Result<Media | null, DomainError>>;
  findByIdWithAuthor(mediaId: string): Promise<Result<MediaWithAuthor | null, DomainError>>;
  listByApartment(
    query: MediaListQuery,
  ): Promise<Result<CursorPage<MediaWithAuthor, string>, DomainError>>;
  reservePendingSlot(params: ReservePendingMediaParams): Promise<Result<void, DomainError>>;
  markUploaded(params: ConfirmMediaUploadedParams): Promise<Result<void, DomainError>>;
  softDelete(params: SoftDeleteMediaParams): Promise<Result<void, DomainError>>;
}
