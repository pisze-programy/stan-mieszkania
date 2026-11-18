import { isErr, isOk } from '@stanmieszkania/shared';
import { describe, expect, it } from 'vitest';
import {
  AUTHOR_COLOR_PALETTE,
  DEFAULT_USER_NAME_PREFIX,
  DELETED_USER_DISPLAY_NAME,
  DISPLAY_NAME_MAX_LENGTH,
  SHORT_TAG_ALPHABET,
  SHORT_TAG_LENGTH,
} from './identity.constants';
import { IDENTITY_ERROR_CODES } from './identity.errors';
import {
  anonymizeUser,
  createNewUser,
  deriveAuthorColor,
  deriveShortTag,
  updateUserDisplayName,
} from './user.entity';

describe('User domain entity', () => {
  it('derives deterministic unambiguous shortTag and palette color', () => {
    const tagA = deriveShortTag('firebase-uid-1');
    const tagB = deriveShortTag('firebase-uid-1');
    const tagC = deriveShortTag('firebase-uid-2');

    expect(tagA).toBe(tagB);
    expect(tagA).not.toBe(tagC);
    expect(tagA).toHaveLength(SHORT_TAG_LENGTH);
    for (const char of tagA) {
      expect(SHORT_TAG_ALPHABET.includes(char)).toBe(true);
    }

    const colorA = deriveAuthorColor('firebase-uid-1');
    const colorB = deriveAuthorColor('firebase-uid-1');
    expect(colorA).toBe(colorB);
    expect(AUTHOR_COLOR_PALETTE).toContain(colorA);
  });

  it('creates user with SIwA display name or falls back to Użytkownik #<shortTag>', () => {
    const namedUser = createNewUser({
      id: 'usr-1',
      firebaseUid: 'fb-1',
      displayName: '  Anna Kowalska  ',
      createdAt: '2026-11-18T12:00:00.000Z',
    });
    expect(namedUser.displayName).toBe('Anna Kowalska');
    expect(namedUser.deletedAt).toBeNull();

    const anonymousUser = createNewUser({
      id: 'usr-2',
      firebaseUid: 'fb-2',
      displayName: '   ',
      createdAt: '2026-11-18T12:00:00.000Z',
    });
    expect(anonymousUser.displayName).toBe(`${DEFAULT_USER_NAME_PREFIX}${anonymousUser.shortTag}`);
  });

  it('validates and updates display name, and blocks updates on deleted users', () => {
    const user = createNewUser({
      id: 'usr-1',
      firebaseUid: 'fb-1',
      createdAt: '2026-11-18T12:00:00.000Z',
    });

    const emptyUpdate = updateUserDisplayName(user, '   ');
    expect(isErr(emptyUpdate)).toBe(true);
    if (isErr(emptyUpdate)) {
      expect(emptyUpdate.error.code).toBe(IDENTITY_ERROR_CODES.DISPLAY_NAME_INVALID);
    }

    const tooLongUpdate = updateUserDisplayName(user, 'x'.repeat(DISPLAY_NAME_MAX_LENGTH + 1));
    expect(isErr(tooLongUpdate)).toBe(true);

    const validUpdate = updateUserDisplayName(user, '  Jan Nowak  ');
    expect(isOk(validUpdate)).toBe(true);
    if (isOk(validUpdate)) {
      expect(validUpdate.value.displayName).toBe('Jan Nowak');
    }

    const anonymized = anonymizeUser(user, '2026-11-18T13:00:00.000Z');
    expect(isOk(anonymized)).toBe(true);
    if (isOk(anonymized)) {
      expect(anonymized.value.firebaseUid).toBeNull();
      expect(anonymized.value.displayName).toBe(DELETED_USER_DISPLAY_NAME);
      expect(anonymized.value.deletedAt).toBe('2026-11-18T13:00:00.000Z');

      const updateAfterDelete = updateUserDisplayName(anonymized.value, 'New Name');
      expect(isErr(updateAfterDelete)).toBe(true);
      if (isErr(updateAfterDelete)) {
        expect(updateAfterDelete.error.code).toBe(IDENTITY_ERROR_CODES.USER_DELETED);
      }

      const secondAnonymize = anonymizeUser(anonymized.value, '2026-11-18T14:00:00.000Z');
      expect(isErr(secondAnonymize)).toBe(true);
    }
  });
});
