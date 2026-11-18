import { HTTP_STATUS } from '@stanmieszkania/http-contracts';
import { createDomainError } from '@stanmieszkania/shared';
import type { Context } from 'hono';
import { respondDomainError } from '../../../http/domain-error-to-http.mapper';
import { COMMON_ERROR_CODES } from '../../../http/http.constants';
import type { AuthenticatedUser } from '../../../http/http-env';
import type { Media } from '../domain/media.entity';
import type { MediaWithAuthor } from '../domain/media.repository';
import type { MediaDto, MediaWithAuthorDto } from './media.schema';

export function toMediaDto(media: Media): MediaDto {
  return {
    id: media.id,
    apartmentId: media.apartmentId,
    authorId: media.authorId,
    kind: media.kind,
    source: media.source,
    uploadStatus: media.uploadStatus,
    sha256: media.sha256,
    capturedAt: media.capturedAt,
    capturedTz: media.capturedTz,
    capturedAtFromImport: media.capturedAtFromImport,
    serverReceivedAt: media.serverReceivedAt,
    width: media.width,
    height: media.height,
    bytes: media.bytes,
    deletedAt: media.deletedAt,
    deletedBy: media.deletedBy,
  };
}

export function toMediaWithAuthorDto(entry: MediaWithAuthor): MediaWithAuthorDto {
  return {
    ...toMediaDto(entry.media),
    author: { ...entry.author },
  };
}

export function requireAuthUser(
  c: Context,
  user: AuthenticatedUser | undefined,
  requestId: string,
) {
  if (user !== undefined) {
    return { ok: true as const, user };
  }
  return {
    ok: false as const,
    response: respondDomainError(
      c,
      createDomainError(
        COMMON_ERROR_CODES.AUTH_TOKEN_MISSING,
        'Authorization bearer token is missing',
      ),
      requestId,
      [HTTP_STATUS.UNAUTHORIZED],
    ),
  };
}
