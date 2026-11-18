import { err, ok, type Result } from '@stanmieszkania/shared';
import { SHA256_HEX_LENGTH, SHA256_HEX_REGEX } from './media.constants';
import { mediaInvalidSha256Error, type MediaError } from './media.errors';

export function normalizeSha256Hash(raw: string): Result<string, MediaError> {
  const normalized = raw.trim().toLowerCase();
  if (normalized.length !== SHA256_HEX_LENGTH || !SHA256_HEX_REGEX.test(normalized)) {
    return err(
      mediaInvalidSha256Error(
        `SHA-256 hash must be a ${String(SHA256_HEX_LENGTH)}-character hexadecimal string`,
      ),
    );
  }
  return ok(normalized);
}
