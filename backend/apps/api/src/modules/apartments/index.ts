export {
  APARTMENT_CHANGE_FIELDS,
  APARTMENT_CITY_MAX_LENGTH,
  APARTMENT_CITY_MIN_LENGTH,
  APARTMENT_NAME_MAX_LENGTH,
  APARTMENT_NAME_MIN_LENGTH,
  APARTMENT_STREET_MAX_LENGTH,
  APARTMENT_STREET_MIN_LENGTH,
  INITIAL_CLOUD_MEDIA_COUNT,
  INVITE_CODE_ALPHABET,
  INVITE_CODE_GROUP_LENGTH,
  INVITE_CODE_RAW_LENGTH,
  INVITE_CODE_SEPARATOR,
  ORPHAN_APARTMENT_RETENTION_DAYS,
} from './domain/apartments.constants';
export {
  APARTMENT_ERROR_CODES,
  apartmentAccessDeniedError,
  apartmentNotFoundError,
  apartmentOwnerRequiredError,
  apartmentValidationFailedError,
  inviteCodeCollisionError,
  inviteCodeInvalidError,
  type ApartmentError,
  type ApartmentErrorCode,
} from './domain/apartments.errors';
export {
  formatInviteCode,
  generateInviteCode,
  normalizeInviteCode,
} from './domain/invite-code.value-object';
export {
  computeApartmentChanges,
  type ApartmentChange,
  type ApartmentChangeField,
  type ApartmentMetadataValues,
  type ComputeApartmentChangesInput,
} from './domain/apartment-change.entity';
export {
  applyApartmentMetadataUpdate,
  createApartment,
  rotateInviteCode,
  shouldSuggestInviteCodeReset,
  validateApartmentMetadata,
  type Apartment,
  type AppliedApartmentUpdate,
  type ApplyApartmentMetadataUpdateInput,
  type CreateApartmentInput,
} from './domain/apartment.entity';
export {
  resolveOwnerDeparture,
  type ActiveContributor,
  type OwnerDepartureResolution,
  type OwnerDepartureTrigger,
  type ResolveOwnerDepartureInput,
} from './domain/ownership-transfer.policy';
export type {
  ApartmentListEntry,
  ApartmentMemberRole,
  ApartmentRepository,
  CreateApartmentWithOwnerParams,
  RotateInviteCodeParams,
  TransferOwnershipAndLeaveParams,
  UpdateApartmentWithChangesParams,
} from './domain/apartment.repository';
