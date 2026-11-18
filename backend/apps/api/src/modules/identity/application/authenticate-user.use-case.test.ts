import { createDomainError, err, isErr, isOk } from '@stanmieszkania/shared';
import { FixedClock, SequentialUuidV7Generator } from '@stanmieszkania/testing';
import { describe, expect, it } from 'vitest';
import { DEFAULT_USER_NAME_PREFIX } from '../domain/identity.constants';
import { IDENTITY_ERROR_CODES } from '../domain/identity.errors';
import { anonymizeUser, createNewUser } from '../domain/user.entity';
import type { UserRepository } from '../domain/user.repository';
import { createLocalDevTokenVerifier } from '../infrastructure/local-dev-token-verifier';
import { InMemoryUserRepository } from '../testing/in-memory-user.repository';
import { createAuthenticateUserUseCase } from './authenticate-user.use-case';

describe('authenticateUserUseCase', () => {
  it('creates a new user on first login and returns existing user on repeat login', async () => {
    const userRepository = new InMemoryUserRepository();
    const useCase = createAuthenticateUserUseCase({
      tokenVerifier: createLocalDevTokenVerifier(),
      userRepository,
      idGenerator: new SequentialUuidV7Generator(),
      clock: new FixedClock(),
    });

    const first = await useCase.execute('dev:fb-1:Anna%20K');
    expect(isOk(first)).toBe(true);
    if (isOk(first)) {
      expect(first.value.firebaseUid).toBe('fb-1');
      expect(first.value.displayName).toBe('Anna K');
    }

    const second = await useCase.execute('dev:fb-1:Different%20Name');
    expect(isOk(second)).toBe(true);
    if (isOk(first) && isOk(second)) {
      expect(second.value).toEqual(first.value);
    }
    expect(userRepository.getAll()).toHaveLength(1);
  });

  it('falls back to default generated name when token omits displayName', async () => {
    const userRepository = new InMemoryUserRepository();
    const useCase = createAuthenticateUserUseCase({
      tokenVerifier: createLocalDevTokenVerifier(),
      userRepository,
      idGenerator: new SequentialUuidV7Generator(),
      clock: new FixedClock(),
    });

    const result = await useCase.execute('dev:fb-anon');
    expect(isOk(result)).toBe(true);
    if (isOk(result)) {
      expect(result.value.displayName).toBe(`${DEFAULT_USER_NAME_PREFIX}${result.value.shortTag}`);
    }
  });

  it('rejects deleted accounts with USER_DELETED', async () => {
    const userRepository = new InMemoryUserRepository();
    const user = createNewUser({
      id: 'usr-del',
      firebaseUid: 'fb-del',
      createdAt: '2026-11-18T12:00:00.000Z',
    });
    const deleted = anonymizeUser(user, '2026-11-18T13:00:00.000Z');
    if (isOk(deleted)) {
      userRepository.seed({ ...deleted.value, firebaseUid: 'fb-del' });
    }

    const useCase = createAuthenticateUserUseCase({
      tokenVerifier: createLocalDevTokenVerifier(),
      userRepository,
      idGenerator: new SequentialUuidV7Generator(),
      clock: new FixedClock(),
    });

    const result = await useCase.execute('dev:fb-del');
    expect(isErr(result)).toBe(true);
    if (isErr(result)) {
      expect(result.error.code).toBe(IDENTITY_ERROR_CODES.USER_DELETED);
    }
  });

  it('recovers when concurrent first-login insert hits unique constraint race', async () => {
    const baseRepo = new InMemoryUserRepository();
    const winner = createNewUser({
      id: 'usr-winner',
      firebaseUid: 'fb-race',
      displayName: 'Winner',
      createdAt: '2026-11-18T12:00:00.000Z',
    });
    let findCalls = 0;

    const racingRepo: UserRepository = {
      findById: (id) => baseRepo.findById(id),
      findByFirebaseUid: async (uid) => {
        findCalls += 1;
        if (findCalls === 1) {
          return Promise.resolve({ ok: true, value: null });
        }
        return baseRepo.findByFirebaseUid(uid);
      },
      insert: async () => {
        baseRepo.seed(winner);
        return Promise.resolve(err(createDomainError('DB_EXECUTION_FAILED', 'UNIQUE constraint')));
      },
      updateDisplayName: (id, name) => baseRepo.updateDisplayName(id, name),
      anonymize: (id, deletedAt) => baseRepo.anonymize(id, deletedAt),
    };

    const useCase = createAuthenticateUserUseCase({
      tokenVerifier: createLocalDevTokenVerifier(),
      userRepository: racingRepo,
      idGenerator: new SequentialUuidV7Generator(),
      clock: new FixedClock(),
    });

    const result = await useCase.execute('dev:fb-race');
    expect(isOk(result)).toBe(true);
    if (isOk(result)) {
      expect(result.value).toEqual(winner);
    }
  });
});
