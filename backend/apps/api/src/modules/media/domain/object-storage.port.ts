import type { DomainError, Result } from '@stanmieszkania/shared';

export interface PresignedUrl {
  readonly url: string;
  readonly expiresAt: string;
}

export interface CreatePresignedPutUrlParams {
  readonly r2Key: string;
  readonly contentType: string;
  readonly bytes: number;
  readonly sha256: string;
  readonly expiresInMs: number;
}

export interface CreatePresignedGetUrlParams {
  readonly r2Key: string;
  readonly expiresInMs: number;
}

export interface UploadedObjectMetadata {
  readonly bytes: number;
  readonly sha256: string | null;
  readonly etag: string | null;
}

export interface ObjectStoragePort {
  createPresignedPutUrl(
    params: CreatePresignedPutUrlParams,
  ): Promise<Result<PresignedUrl, DomainError>>;
  createPresignedGetUrl(
    params: CreatePresignedGetUrlParams,
  ): Promise<Result<PresignedUrl, DomainError>>;
  headObject(r2Key: string): Promise<Result<UploadedObjectMetadata | null, DomainError>>;
  readObjectSha256(r2Key: string): Promise<Result<string | null, DomainError>>;
}
