export {
  AUTHOR_COLOR_PALETTE,
  DEFAULT_USER_NAME_PREFIX,
  DELETED_USER_DISPLAY_NAME,
  DISPLAY_NAME_MAX_LENGTH,
  DISPLAY_NAME_MIN_LENGTH,
  SHORT_TAG_ALPHABET,
  SHORT_TAG_LENGTH,
} from './domain/identity.constants';
export {
  IDENTITY_ERROR_CODES,
  authTokenInvalidError,
  authTokenMissingError,
  displayNameInvalidError,
  userDeletedError,
  userNotFoundError,
  type IdentityError,
  type IdentityErrorCode,
} from './domain/identity.errors';
export {
  anonymizeUser,
  createNewUser,
  deriveAuthorColor,
  deriveShortTag,
  normalizeDisplayName,
  updateUserDisplayName,
  type CreateNewUserInput,
  type User,
} from './domain/user.entity';
export type { TokenVerifierPort, VerifiedIdentityClaims } from './domain/token-verifier.port';
export type { UserRepository } from './domain/user.repository';
export { USERS_TABLE, userRowSchema, type UserRow } from './infrastructure/users.table';
export { createD1UserRepository } from './infrastructure/d1-user.repository';
export { InMemoryUserRepository } from './testing/in-memory-user.repository';
