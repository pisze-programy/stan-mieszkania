import { err, ok, type Result } from '@stanmieszkania/shared';
import { mediaValidationFailedError, quotaExceededError, type MediaError } from './media.errors';

// Decision S2-5: Soft-deleted media never free quota; cloudMediaCount counts all confirmed/pending slots ever consumed.
export function canReserveCloudMediaSlot(
  cloudMediaCount: number,
  quota: number,
): Result<void, MediaError> {
  if (!Number.isInteger(cloudMediaCount) || cloudMediaCount < 0) {
    return err(
      mediaValidationFailedError('cloudMediaCount must be a non-negative integer', {
        cloudMediaCount,
      }),
    );
  }
  if (!Number.isInteger(quota) || quota < 1) {
    return err(mediaValidationFailedError('quota must be a positive integer', { quota }));
  }
  if (cloudMediaCount >= quota) {
    return err(quotaExceededError(cloudMediaCount, quota));
  }
  return ok(undefined);
}
