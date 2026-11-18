import type { DomainError, Result } from '@stanmieszkania/shared';
import type { Media } from './media.entity';

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
  findById(mediaId: string): Promise<Result<Media | null, DomainError>>;
  listByApartment(apartmentId: string): Promise<Result<readonly Media[], DomainError>>;
  reservePendingSlot(params: ReservePendingMediaParams): Promise<Result<void, DomainError>>;
  markUploaded(params: ConfirmMediaUploadedParams): Promise<Result<void, DomainError>>;
  softDelete(params: SoftDeleteMediaParams): Promise<Result<void, DomainError>>;
}
