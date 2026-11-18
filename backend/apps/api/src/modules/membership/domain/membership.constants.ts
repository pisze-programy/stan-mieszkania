export const MEMBERSHIP_ROLES = {
  OWNER: 'owner',
  CONTRIBUTOR: 'contributor',
} as const;

export const MEMBERSHIP_CHANGE_LOG_ENTITY_TYPE = 'membership';

export const MEMBERSHIP_CHANGE_LOG_OPS = {
  JOINED: 'joined',
  REVOKED: 'revoked',
  LEFT: 'left',
} as const;

export const JOIN_REQUEST_INVITE_CODE_MIN_LENGTH = 1;
export const JOIN_REQUEST_INVITE_CODE_MAX_LENGTH = 64;
