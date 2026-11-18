export {
  APARTMENT_CHANGE_FIELDS,
  APARTMENT_CITY_MAX_LENGTH,
  APARTMENT_CITY_MIN_LENGTH,
  APARTMENT_NAME_MAX_LENGTH,
  APARTMENT_NAME_MIN_LENGTH,
  APARTMENT_ROLES,
  APARTMENT_STREET_MAX_LENGTH,
  APARTMENT_STREET_MIN_LENGTH,
  CHANGE_LOG_ENTITY_TYPES,
  CHANGE_LOG_OPS,
  INITIAL_CLOUD_MEDIA_COUNT,
  INVITE_CODE_ALPHABET,
  INVITE_CODE_GROUP_LENGTH,
  INVITE_CODE_RAW_LENGTH,
  INVITE_CODE_SEPARATOR,
  MAX_INVITE_CODE_GENERATION_ATTEMPTS,
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
  LeaveAsContributorParams,
  RotateInviteCodeParams,
  TransferOwnershipAndLeaveParams,
  UpdateApartmentWithChangesParams,
} from './domain/apartment.repository';
export {
  createCreateApartmentUseCase,
  type CreateApartmentCommand,
  type CreateApartmentDeps,
  type CreateApartmentUseCase,
} from './application/create-apartment.use-case';
export {
  createDeleteOrLeaveApartmentUseCase,
  type DeleteOrLeaveApartmentCommand,
  type DeleteOrLeaveApartmentDeps,
  type DeleteOrLeaveApartmentUseCase,
} from './application/delete-or-leave-apartment.use-case';
export {
  createGetApartmentUseCase,
  type GetApartmentDeps,
  type GetApartmentQuery,
  type GetApartmentUseCase,
} from './application/get-apartment.use-case';
export {
  createListApartmentChangesUseCase,
  type ListApartmentChangesDeps,
  type ListApartmentChangesQuery,
  type ListApartmentChangesUseCase,
} from './application/list-apartment-changes.use-case';
export {
  createListMyApartmentsUseCase,
  type ListMyApartmentsDeps,
  type ListMyApartmentsUseCase,
} from './application/list-my-apartments.use-case';
export {
  createResetInviteCodeUseCase,
  type ResetInviteCodeCommand,
  type ResetInviteCodeDeps,
  type ResetInviteCodeUseCase,
} from './application/reset-invite-code.use-case';
export {
  createUpdateApartmentUseCase,
  type UpdateApartmentCommand,
  type UpdateApartmentDeps,
  type UpdateApartmentUseCase,
} from './application/update-apartment.use-case';
export {
  APARTMENTS_TABLE,
  apartmentRowSchema,
  type ApartmentRow,
} from './infrastructure/apartments.table';
export {
  APARTMENT_CHANGES_TABLE,
  apartmentChangeRowSchema,
  type ApartmentChangeRow,
} from './infrastructure/apartment-changes.table';
export { createD1ApartmentRepository } from './infrastructure/d1-apartment.repository';
export {
  ApartmentChangeDtoSchema,
  ApartmentChangeFieldSchema,
  ApartmentDtoSchema,
  ApartmentHistoryResponseSchema,
  ApartmentIdParamsSchema,
  ApartmentListResponseSchema,
  ApartmentRoleSchema,
  UpdateApartmentRequestSchema,
  UpsertApartmentRequestSchema,
  type ApartmentChangeDto,
  type ApartmentDto,
} from './http/apartments.schema';
export {
  deleteApartmentRoute,
  getApartmentRoute,
  listApartmentHistoryRoute,
  listApartmentsRoute,
  patchApartmentRoute,
  putApartmentRoute,
  resetInviteCodeRoute,
} from './http/apartments.route-defs';
export { createApartmentsRoutes, type ApartmentRouteHandlers } from './http/apartments.routes';
export { InMemoryApartmentRepository } from './testing/in-memory-apartment.repository';
