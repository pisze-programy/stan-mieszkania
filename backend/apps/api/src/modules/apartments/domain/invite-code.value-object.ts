import { err, ok, type Result } from '@stanmieszkania/shared';
import {
  INVITE_CODE_ALPHABET,
  INVITE_CODE_GROUP_LENGTH,
  INVITE_CODE_RAW_LENGTH,
  INVITE_CODE_SEPARATOR,
} from './apartments.constants';
import { inviteCodeInvalidError, type ApartmentError } from './apartments.errors';

export function formatInviteCode(rawChars: string): string {
  return `${rawChars.slice(0, INVITE_CODE_GROUP_LENGTH)}${INVITE_CODE_SEPARATOR}${rawChars.slice(INVITE_CODE_GROUP_LENGTH)}`;
}

export function generateInviteCode(randomBytes?: Uint8Array): string {
  const bytes = new Uint8Array(INVITE_CODE_RAW_LENGTH);
  if (randomBytes !== undefined) {
    if (randomBytes.length < INVITE_CODE_RAW_LENGTH) {
      throw new RangeError(
        `Invite code randomBytes must have at least ${String(INVITE_CODE_RAW_LENGTH)} bytes`,
      );
    }
    bytes.set(randomBytes.subarray(0, INVITE_CODE_RAW_LENGTH));
  } else {
    globalThis.crypto.getRandomValues(bytes);
  }

  let chars = '';
  for (let index = 0; index < INVITE_CODE_RAW_LENGTH; index += 1) {
    const byte = bytes[index] ?? 0;
    chars += INVITE_CODE_ALPHABET.charAt(byte % INVITE_CODE_ALPHABET.length);
  }
  return formatInviteCode(chars);
}

export function normalizeInviteCode(raw: string): Result<string, ApartmentError> {
  const cleaned = raw.toUpperCase().replace(/[\s-]+/g, '');
  if (cleaned.length !== INVITE_CODE_RAW_LENGTH) {
    return err(
      inviteCodeInvalidError(
        `Invite code must contain ${String(INVITE_CODE_RAW_LENGTH)} characters`,
      ),
    );
  }

  for (let index = 0; index < cleaned.length; index += 1) {
    const ch = cleaned.charAt(index);
    if (!INVITE_CODE_ALPHABET.includes(ch)) {
      return err(inviteCodeInvalidError(`Invite code contains unsupported character "${ch}"`));
    }
  }

  return ok(formatInviteCode(cleaned));
}
