import { isErr, isOk } from '@stanmieszkania/shared';
import { describe, expect, it } from 'vitest';
import { IDENTITY_ERROR_CODES } from '../domain/identity.errors';
import { anonymizeUser, createNewUser } from '../domain/user.entity';
import { InMemoryUserRepository } from '../testing/in-memory-user.repository';
import { createUpdateDisplayNameUseCase } from './update-display-name.use-case';

describe('updateDisplayNameUseCase', () => {
  it('updates displayName for an active user', async () => {
    const userRepository = new InMemoryUserRepository();
    const user = createNewUser({
      id: 'usr-1',
      firebaseUid: 'fb-1',
      createdAt: '2026-11-18T12:00:00.000Z',
    });
    userRepository.seed(user);

    const useCase = createUpdateDisplayNameUseCase({ userRepository });
    const result = await useCase.execute({ userId: user.id, displayName: '  Jan Kowalski  ' });

    expect(isOk(result)).toBe(true);
    if (isOk(result)) {
      expect(result.value.displayName).toBe('Jan Kowalski');
    }
  });

  it('returns USER_NOT_FOUND, DISPLAY_NAME_INVALID, and USER_DELETED errors', async () => {
    const userRepository = new InMemoryUserRepository();
    const useCase = createUpdateDisplayNameUseCase({ userRepository });

    const missing = await useCase.execute({ userId: 'missing', displayName: 'Jan' });
    expect(isErr(missing)).toBe(true);
    if (isErr(missing)) {
      expect(missing.error.code).toBe(IDENTITY_ERROR_CODES.USER_NOT_FOUND);
    }

    const active = createNewUser({
      id: 'usr-2',
      firebaseUid: 'fb-2',
      createdAt: '2026-11-18T12:00:00.000Z',
    });
    userRepository.seed(active);

    const invalid = await useCase.execute({ userId: active.id, displayName: '   ' });
    expect(isErr(invalid)).toBe(true);
    if (isErr(invalid)) {
      expect(invalid.error.code).toBe(IDENTITY_ERROR_CODES.DISPLAY_NAME_INVALID);
    }

    const anonymized = anonymizeUser(active, '2026-11-18T13:00:00.000Z');
    if (isOk(anonymized)) {
      userRepository.seed(anonymized.value);
    }
    const deleted = await useCase.execute({ userId: active.id, displayName: 'Jan' });
    expect(isErr(deleted)).toBe(true);
    if (isErr(deleted)) {
      expect(deleted.error.code).toBe(IDENTITY_ERROR_CODES.USER_DELETED);
    }
  });
});
