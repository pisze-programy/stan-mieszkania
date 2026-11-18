import { isErr, isOk } from '@stanmieszkania/shared';
import { describe, expect, it } from 'vitest';
import { canReserveCloudMediaSlot } from './media-quota.policy';
import { MEDIA_ERROR_CODES } from './media.errors';

describe('media-quota.policy', () => {
  it('allows reserving a slot below quota and returns QUOTA_EXCEEDED at or above quota', () => {
    expect(isOk(canReserveCloudMediaSlot(0, 250))).toBe(true);
    expect(isOk(canReserveCloudMediaSlot(249, 250))).toBe(true);

    const atLimit = canReserveCloudMediaSlot(250, 250);
    expect(isErr(atLimit) && atLimit.error.code).toBe(MEDIA_ERROR_CODES.QUOTA_EXCEEDED);

    const overLimit = canReserveCloudMediaSlot(251, 250);
    expect(isErr(overLimit) && overLimit.error.code).toBe(MEDIA_ERROR_CODES.QUOTA_EXCEEDED);
  });

  it('rejects negative counts or non-positive quota with MEDIA_VALIDATION_FAILED', () => {
    const negativeCount = canReserveCloudMediaSlot(-1, 250);
    expect(isErr(negativeCount) && negativeCount.error.code).toBe(
      MEDIA_ERROR_CODES.MEDIA_VALIDATION_FAILED,
    );

    const zeroQuota = canReserveCloudMediaSlot(0, 0);
    expect(isErr(zeroQuota) && zeroQuota.error.code).toBe(
      MEDIA_ERROR_CODES.MEDIA_VALIDATION_FAILED,
    );
  });
});
