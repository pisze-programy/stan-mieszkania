import { err, ok, type Clock, type DomainError, type Result } from '@stanmieszkania/shared';
import { createApartment } from '../domain/apartment.entity';
import type { ApartmentListEntry, ApartmentRepository } from '../domain/apartment.repository';
import {
  APARTMENT_ROLES,
  MAX_INVITE_CODE_GENERATION_ATTEMPTS,
} from '../domain/apartments.constants';
import { apartmentAccessDeniedError, inviteCodeCollisionError } from '../domain/apartments.errors';
import { generateInviteCode } from '../domain/invite-code.value-object';

export interface CreateApartmentDeps {
  readonly apartmentRepository: ApartmentRepository;
  readonly clock: Clock;
  readonly generateCode?: () => string;
}

export interface CreateApartmentCommand {
  readonly apartmentId: string;
  readonly ownerId: string;
  readonly name: string;
  readonly street: string;
  readonly city: string;
}

export interface CreateApartmentUseCase {
  execute(input: CreateApartmentCommand): Promise<Result<ApartmentListEntry, DomainError>>;
}

async function resolveExistingEntry(
  apartmentRepository: ApartmentRepository,
  apartmentId: string,
  callerId: string,
): Promise<Result<ApartmentListEntry | null, DomainError>> {
  const existing = await apartmentRepository.findById(apartmentId);
  if (!existing.ok) {
    return existing;
  }
  if (existing.value === null) {
    return ok(null);
  }
  if (existing.value.ownerId !== callerId) {
    return err(apartmentAccessDeniedError(apartmentId));
  }
  const latest = await apartmentRepository.getLatestContributorJoinedAt(apartmentId);
  if (!latest.ok) {
    return latest;
  }
  return ok({
    apartment: existing.value,
    role: APARTMENT_ROLES.OWNER,
    latestContributorJoinedAt: latest.value,
  });
}

export function createCreateApartmentUseCase(deps: CreateApartmentDeps): CreateApartmentUseCase {
  const codeGenerator = deps.generateCode ?? generateInviteCode;

  return {
    execute: async (input) => {
      const existing = await resolveExistingEntry(
        deps.apartmentRepository,
        input.apartmentId,
        input.ownerId,
      );
      if (!existing.ok) {
        return existing;
      }
      if (existing.value !== null) {
        return ok(existing.value);
      }

      const nowIso = deps.clock.nowIso();

      for (let attempt = 0; attempt < MAX_INVITE_CODE_GENERATION_ATTEMPTS; attempt += 1) {
        const inviteCode = codeGenerator();
        const collision = await deps.apartmentRepository.findByInviteCode(inviteCode);
        if (!collision.ok) {
          return collision;
        }
        if (collision.value !== null) {
          continue;
        }

        const built = createApartment({
          id: input.apartmentId,
          ownerId: input.ownerId,
          name: input.name,
          street: input.street,
          city: input.city,
          inviteCode,
          createdAt: nowIso,
        });
        if (!built.ok) {
          return built;
        }

        const inserted = await deps.apartmentRepository.createWithOwnerMembership({
          apartment: built.value,
          joinedAt: nowIso,
        });
        if (inserted.ok) {
          return ok({
            apartment: built.value,
            role: APARTMENT_ROLES.OWNER,
            latestContributorJoinedAt: null,
          });
        }

        const replay = await resolveExistingEntry(
          deps.apartmentRepository,
          input.apartmentId,
          input.ownerId,
        );
        if (!replay.ok) {
          return replay;
        }
        if (replay.value !== null) {
          return ok(replay.value);
        }
      }

      return err(inviteCodeCollisionError());
    },
  };
}
