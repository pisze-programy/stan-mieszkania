import { err, ok, type DomainError, type Result } from '@stanmieszkania/shared';
import { userNotFoundError } from '../domain/identity.errors';
import { updateUserDisplayName, type User } from '../domain/user.entity';
import type { UserRepository } from '../domain/user.repository';

export interface UpdateDisplayNameDeps {
  readonly userRepository: UserRepository;
}

export interface UpdateDisplayNameInput {
  readonly userId: string;
  readonly displayName: string;
}

export interface UpdateDisplayNameUseCase {
  execute(input: UpdateDisplayNameInput): Promise<Result<User, DomainError>>;
}

export function createUpdateDisplayNameUseCase(
  deps: UpdateDisplayNameDeps,
): UpdateDisplayNameUseCase {
  return {
    execute: async (input) => {
      const found = await deps.userRepository.findById(input.userId);
      if (!found.ok) {
        return found;
      }

      if (found.value === null) {
        return err(userNotFoundError(input.userId));
      }

      const updated = updateUserDisplayName(found.value, input.displayName);
      if (!updated.ok) {
        return updated;
      }

      const persisted = await deps.userRepository.updateDisplayName(
        updated.value.id,
        updated.value.displayName,
      );
      if (!persisted.ok) {
        return persisted;
      }

      return ok(updated.value);
    },
  };
}
