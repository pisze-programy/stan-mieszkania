import { err, ok, type Clock, type DomainError, type Result } from '@stanmieszkania/shared';
import { rotateInviteCode } from '../domain/apartment.entity';
import type { ApartmentListEntry, ApartmentRepository } from '../domain/apartment.repository';
import {
  APARTMENT_ROLES,
  MAX_INVITE_CODE_GENERATION_ATTEMPTS,
} from '../domain/apartments.constants';
import {
  apartmentAccessDeniedError,
  apartmentNotFoundError,
  apartmentOwnerRequiredError,
  inviteCodeCollisionError,
} from '../domain/apartments.errors';
import { generateInviteCode } from '../domain/invite-code.value-object';

export interface ResetInviteCodeDeps {
  readonly apartmentRepository: ApartmentRepository;
  readonly clock: Clock;
  readonly generateCode?: () => string;
}

export interface ResetInviteCodeCommand {
  readonly apartmentId: string;
  readonly userId: string;
}

export interface ResetInviteCodeUseCase {
  execute(input: ResetInviteCodeCommand): Promise<Result<ApartmentListEntry, DomainError>>;
}

export function createResetInviteCodeUseCase(deps: ResetInviteCodeDeps): ResetInviteCodeUseCase {
  const codeGenerator = deps.generateCode ?? generateInviteCode;

  return {
    execute: async (input) => {
      const found = await deps.apartmentRepository.findById(input.apartmentId);
      if (!found.ok) {
        return found;
      }
      if (found.value === null) {
        return err(apartmentNotFoundError(input.apartmentId));
      }

      const role = await deps.apartmentRepository.findActiveRole(input.apartmentId, input.userId);
      if (!role.ok) {
        return role;
      }
      if (role.value === null) {
        return err(apartmentAccessDeniedError(input.apartmentId));
      }
      if (role.value !== APARTMENT_ROLES.OWNER) {
        return err(apartmentOwnerRequiredError(input.apartmentId));
      }

      const currentCode = found.value.inviteCode;
      for (let attempt = 0; attempt < MAX_INVITE_CODE_GENERATION_ATTEMPTS; attempt += 1) {
        const candidate = codeGenerator();
        if (candidate === currentCode) {
          continue;
        }

        const existing = await deps.apartmentRepository.findByInviteCode(candidate);
        if (!existing.ok) {
          return existing;
        }
        if (existing.value !== null) {
          continue;
        }

        const rotatedAt = deps.clock.nowIso();
        const rotated = rotateInviteCode(found.value, candidate, rotatedAt);
        const persisted = await deps.apartmentRepository.rotateInviteCode({
          apartmentId: found.value.id,
          inviteCode: candidate,
          rotatedAt,
        });
        if (!persisted.ok) {
          return persisted;
        }

        const latest = await deps.apartmentRepository.getLatestContributorJoinedAt(
          input.apartmentId,
        );
        if (!latest.ok) {
          return latest;
        }

        return ok({
          apartment: rotated,
          role: APARTMENT_ROLES.OWNER,
          latestContributorJoinedAt: latest.value,
        });
      }

      return err(inviteCodeCollisionError());
    },
  };
}
