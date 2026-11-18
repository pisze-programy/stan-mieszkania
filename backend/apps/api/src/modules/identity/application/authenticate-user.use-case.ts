import {
  err,
  ok,
  type Clock,
  type DomainError,
  type IdGenerator,
  type Result,
} from '@stanmieszkania/shared';
import type { TokenVerifierPort } from '../domain/token-verifier.port';
import { createNewUser, type User } from '../domain/user.entity';
import type { UserRepository } from '../domain/user.repository';
import { userDeletedError } from '../domain/identity.errors';

export interface AuthenticateUserDeps {
  readonly tokenVerifier: TokenVerifierPort;
  readonly userRepository: UserRepository;
  readonly idGenerator: IdGenerator;
  readonly clock: Clock;
}

export interface AuthenticateUserUseCase {
  execute(idToken: string): Promise<Result<User, DomainError>>;
}

export function createAuthenticateUserUseCase(deps: AuthenticateUserDeps): AuthenticateUserUseCase {
  return {
    execute: async (idToken) => {
      const verified = await deps.tokenVerifier.verifyIdToken(idToken);
      if (!verified.ok) {
        return verified;
      }

      const existing = await deps.userRepository.findByFirebaseUid(verified.value.firebaseUid);
      if (!existing.ok) {
        return existing;
      }

      if (existing.value !== null) {
        if (existing.value.deletedAt !== null) {
          return err(userDeletedError(existing.value.id));
        }
        return ok(existing.value);
      }

      const newUser = createNewUser({
        id: deps.idGenerator.nextId(),
        firebaseUid: verified.value.firebaseUid,
        ...(verified.value.displayName !== undefined
          ? { displayName: verified.value.displayName }
          : {}),
        createdAt: deps.clock.nowIso(),
      });

      const inserted = await deps.userRepository.insert(newUser);
      if (inserted.ok) {
        return ok(newUser);
      }

      // Recover from concurrent first-login insert race on UNIQUE(firebase_uid).
      const retryFound = await deps.userRepository.findByFirebaseUid(verified.value.firebaseUid);
      if (retryFound.ok && retryFound.value !== null) {
        if (retryFound.value.deletedAt !== null) {
          return err(userDeletedError(retryFound.value.id));
        }
        return ok(retryFound.value);
      }

      return inserted;
    },
  };
}
