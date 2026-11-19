export {
  DECIMAL_RADIX,
  ENTRY_CHANGE_LOG_ENTITY_TYPE,
  ENTRY_CHANGE_LOG_OPS,
  ENTRY_TEXT_MAX_LENGTH,
  ENTRY_TEXT_MIN_LENGTH,
  MARKER_CHANGE_LOG_ENTITY_TYPE,
  MARKER_COORD_MAX,
  MARKER_COORD_MIN,
  MARKER_TOKEN_REGEX,
  MIN_MARKER_NUMBER,
  REDACTED_ENTRY_TEXT,
} from './domain/entries.constants';
export {
  ENTRY_ERROR_CODES,
  entryAccessDeniedError,
  entryAlreadyRetractedError,
  entryAuthorRequiredError,
  entryConflictError,
  entryMediaNotReadyError,
  entryNotFoundError,
  entryValidationFailedError,
  markerDuplicateLocalNumberError,
  markerInvalidCoordinatesError,
  type EntryError,
  type EntryErrorCode,
} from './domain/entries.errors';
export { validateDraftMarkers, type DraftMarkerInput, type Marker } from './domain/marker.entity';
export {
  assignGlobalMarkerNumbers,
  type AssignGlobalMarkerNumbersInput,
  type AssignGlobalMarkerNumbersOutput,
  type AssignedMarkerMapping,
} from './domain/marker-numbering.policy';
export {
  canAttachEntryToMedia,
  createVerifiedEntry,
  isEntryRetracted,
  isEntryVerified,
  retractEntry,
  type CreateVerifiedEntryInput,
  type CreateVerifiedEntryResult,
  type Entry,
  type RetractEntryInput,
  type TargetMediaReadiness,
} from './domain/entry.entity';
export type {
  ApartmentEntryAccess,
  EntryAuthorSummary,
  EntryRepository,
  EntryTargetMediaAccess,
  EntryWithAuthor,
  InsertEntryWithMarkersParams,
  RetractEntryParams,
} from './domain/entry.repository';
export {
  createCreateEntryUseCase,
  type CreateEntryCommand,
  type CreateEntryDeps,
  type CreateEntryUseCase,
} from './application/create-entry.use-case';
export {
  createListMediaEntriesUseCase,
  type ListMediaEntriesDeps,
  type ListMediaEntriesQuery,
  type ListMediaEntriesUseCase,
} from './application/list-media-entries.use-case';
export {
  createRetractEntryUseCase,
  type RetractEntryCommand,
  type RetractEntryDeps,
  type RetractEntryUseCase,
} from './application/retract-entry.use-case';
export { ENTRIES_TABLE, entryRowSchema, type EntryRow } from './infrastructure/entries.table';
export { MARKERS_TABLE, markerRowSchema, type MarkerRow } from './infrastructure/markers.table';
export { createD1EntryRepository } from './infrastructure/d1-entry.repository';
export {
  CreateEntryRequestSchema,
  DraftMarkerDtoSchema,
  EntryAuthorDtoSchema,
  EntryDtoSchema,
  EntryListResponseSchema,
  EntryPathParamsSchema,
  MarkerDtoSchema,
  MediaEntriesPathParamsSchema,
  type CreateEntryRequestDto,
  type EntryDto,
} from './http/entries.schema';
export { deleteEntryRoute, listEntriesRoute, putEntryRoute } from './http/entries.route-defs';
export { createEntriesRoutes, type EntriesRouteHandlers } from './http/entries.routes';
export { InMemoryEntryRepository } from './testing/in-memory-entry.repository';
