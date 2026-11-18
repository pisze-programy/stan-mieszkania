import { err, ok, type Result } from '@stanmieszkania/shared';
import {
  AUTHOR_COLOR_PALETTE,
  DEFAULT_USER_NAME_PREFIX,
  DELETED_USER_DISPLAY_NAME,
  DISPLAY_NAME_MAX_LENGTH,
  DISPLAY_NAME_MIN_LENGTH,
  FNV1A_OFFSET_BASIS,
  FNV1A_PRIME,
  HASH_MIX_SHIFT,
  SHORT_TAG_ALPHABET,
  SHORT_TAG_LENGTH,
} from './identity.constants';
import { displayNameInvalidError, userDeletedError, type IdentityError } from './identity.errors';

export interface User {
  readonly id: string;
  readonly firebaseUid: string | null;
  readonly displayName: string;
  readonly shortTag: string;
  readonly color: string;
  readonly createdAt: string;
  readonly deletedAt: string | null;
}

export interface CreateNewUserInput {
  readonly id: string;
  readonly firebaseUid: string;
  readonly displayName?: string | null;
  readonly createdAt: string;
}

function hashSeed(seed: string): number {
  let hash = FNV1A_OFFSET_BASIS;
  for (let index = 0; index < seed.length; index += 1) {
    hash ^= seed.charCodeAt(index);
    hash = Math.imul(hash, FNV1A_PRIME) >>> 0;
  }
  return hash;
}

export function deriveShortTag(seed: string): string {
  let state = hashSeed(seed);
  let tag = '';
  for (let index = 0; index < SHORT_TAG_LENGTH; index += 1) {
    state = Math.imul(state ^ (index + 1), FNV1A_PRIME) >>> 0;
    const charIndex = (state >>> HASH_MIX_SHIFT) % SHORT_TAG_ALPHABET.length;
    tag += SHORT_TAG_ALPHABET.charAt(charIndex);
  }
  return tag;
}

export function deriveAuthorColor(seed: string): string {
  const hash = hashSeed(`color:${seed}`);
  const colorIndex = hash % AUTHOR_COLOR_PALETTE.length;
  return AUTHOR_COLOR_PALETTE[colorIndex] ?? AUTHOR_COLOR_PALETTE[0];
}

export function normalizeDisplayName(rawDisplayName: string): Result<string, IdentityError> {
  const trimmed = rawDisplayName.trim();
  if (trimmed.length < DISPLAY_NAME_MIN_LENGTH) {
    return err(displayNameInvalidError('Display name must not be empty'));
  }
  if (trimmed.length > DISPLAY_NAME_MAX_LENGTH) {
    return err(
      displayNameInvalidError(
        `Display name must not exceed ${String(DISPLAY_NAME_MAX_LENGTH)} characters`,
      ),
    );
  }
  return ok(trimmed);
}

// Decision S2-14: Fallback to 'Użytkownik #<shortTag>' when SIwA omits displayName.
export function createNewUser(input: CreateNewUserInput): User {
  const shortTag = deriveShortTag(input.firebaseUid);
  const color = deriveAuthorColor(input.firebaseUid);
  const trimmedName = input.displayName?.trim() ?? '';
  const displayName =
    trimmedName.length > 0
      ? trimmedName.slice(0, DISPLAY_NAME_MAX_LENGTH)
      : `${DEFAULT_USER_NAME_PREFIX}${shortTag}`;

  return {
    id: input.id,
    firebaseUid: input.firebaseUid,
    displayName,
    shortTag,
    color,
    createdAt: input.createdAt,
    deletedAt: null,
  };
}

export function updateUserDisplayName(
  user: User,
  rawDisplayName: string,
): Result<User, IdentityError> {
  if (user.deletedAt !== null) {
    return err(userDeletedError(user.id));
  }

  const normalized = normalizeDisplayName(rawDisplayName);
  if (!normalized.ok) {
    return normalized;
  }

  return ok({
    ...user,
    displayName: normalized.value,
  });
}

// Decision Q5: Account deletion removes firebaseUid and sets anonymized display name.
export function anonymizeUser(user: User, deletedAt: string): Result<User, IdentityError> {
  if (user.deletedAt !== null) {
    return err(userDeletedError(user.id));
  }

  return ok({
    ...user,
    firebaseUid: null,
    displayName: DELETED_USER_DISPLAY_NAME,
    deletedAt,
  });
}
