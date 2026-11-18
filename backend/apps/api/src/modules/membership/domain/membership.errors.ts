import { createDomainError, type DomainError } from '@stanmieszkania/shared';

export const MEMBERSHIP_ERROR_CODES = {
  MEMBERSHIP_NOT_FOUND: 'MEMBERSHIP_NOT_FOUND',
  MEMBERSHIP_ACCESS_DENIED: 'MEMBERSHIP_ACCESS_DENIED',
  MEMBERSHIP_OWNER_REQUIRED: 'MEMBERSHIP_OWNER_REQUIRED',
  CANNOT_REVOKE_OWNER: 'CANNOT_REVOKE_OWNER',
  INVITE_CODE_NOT_FOUND: 'INVITE_CODE_NOT_FOUND',
  INVITE_CODE_INVALID: 'INVITE_CODE_INVALID',
  INVITE_CODE_RATE_LIMITED: 'INVITE_CODE_RATE_LIMITED',
} as const;

export type MembershipErrorCode =
  (typeof MEMBERSHIP_ERROR_CODES)[keyof typeof MEMBERSHIP_ERROR_CODES];
export type MembershipError = DomainError<MembershipErrorCode>;

export function membershipNotFoundError(apartmentId: string, userId?: string): MembershipError {
  return createDomainError(
    MEMBERSHIP_ERROR_CODES.MEMBERSHIP_NOT_FOUND,
    'Membership was not found',
    {
      apartmentId,
      ...(userId !== undefined ? { userId } : {}),
    },
  );
}

export function membershipAccessDeniedError(apartmentId: string): MembershipError {
  return createDomainError(
    MEMBERSHIP_ERROR_CODES.MEMBERSHIP_ACCESS_DENIED,
    'User does not have active membership in this apartment',
    { apartmentId },
  );
}

export function membershipOwnerRequiredError(apartmentId: string): MembershipError {
  return createDomainError(
    MEMBERSHIP_ERROR_CODES.MEMBERSHIP_OWNER_REQUIRED,
    'Only the apartment owner can perform this action',
    { apartmentId },
  );
}

export function cannotRevokeOwnerError(apartmentId: string): MembershipError {
  return createDomainError(
    MEMBERSHIP_ERROR_CODES.CANNOT_REVOKE_OWNER,
    'Apartment owner cannot be revoked or leave directly; use DELETE /v1/apartments/{apartmentId}',
    { apartmentId },
  );
}

export function inviteCodeNotFoundError(): MembershipError {
  return createDomainError(
    MEMBERSHIP_ERROR_CODES.INVITE_CODE_NOT_FOUND,
    'No active apartment matched the provided invite code',
  );
}

export function inviteCodeInvalidError(message: string): MembershipError {
  return createDomainError(MEMBERSHIP_ERROR_CODES.INVITE_CODE_INVALID, message);
}

export function inviteCodeRateLimitedError(retryAfterSeconds: number): MembershipError {
  return createDomainError(
    MEMBERSHIP_ERROR_CODES.INVITE_CODE_RATE_LIMITED,
    'Too many invite code join attempts; try again later',
    { retryAfterSeconds },
  );
}
