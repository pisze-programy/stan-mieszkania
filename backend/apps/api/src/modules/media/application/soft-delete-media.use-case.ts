import { err, ok, type Clock, type DomainError, type Result } from '@stanmieszkania/shared';
import { softDeleteMedia, type Media } from '../domain/media.entity';
import { mediaAccessDeniedError, mediaNotFoundError } from '../domain/media.errors';
import type { MediaRepository } from '../domain/media.repository';

export interface SoftDeleteMediaDeps {
  readonly mediaRepository: MediaRepository;
  readonly clock: Clock;
}

export interface SoftDeleteMediaCommand {
  readonly apartmentId: string;
  readonly mediaId: string;
  readonly userId: string;
}

export interface SoftDeleteMediaUseCase {
  execute(input: SoftDeleteMediaCommand): Promise<Result<Media, DomainError>>;
}

export function createSoftDeleteMediaUseCase(deps: SoftDeleteMediaDeps): SoftDeleteMediaUseCase {
  return {
    execute: async (input) => {
      const access = await deps.mediaRepository.findApartmentAccess(
        input.apartmentId,
        input.userId,
      );
      if (!access.ok) return access;
      if (access.value === null) return err(mediaNotFoundError(input.mediaId));
      if (!access.value.isActiveMember) return err(mediaAccessDeniedError(input.apartmentId));

      const found = await deps.mediaRepository.findById(input.mediaId);
      if (!found.ok) return found;
      const media = found.value;
      if (media === null || media.apartmentId !== input.apartmentId) {
        return err(mediaNotFoundError(input.mediaId));
      }

      const nowIso = deps.clock.nowIso();
      const deleted = softDeleteMedia(media, { actorUserId: input.userId, nowIso });
      if (!deleted.ok) return deleted;

      if (media.deletedAt === null) {
        const persisted = await deps.mediaRepository.softDelete({
          mediaId: media.id,
          apartmentId: media.apartmentId,
          deletedBy: input.userId,
          deletedAt: nowIso,
        });
        if (!persisted.ok) return persisted;
      }

      return ok(deleted.value);
    },
  };
}
