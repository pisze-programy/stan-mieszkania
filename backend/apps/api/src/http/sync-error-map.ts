import { HTTP_STATUS } from '@stanmieszkania/http-contracts';
import type { HttpErrorMappingEntry } from './http.constants';

export const SYNC_HTTP_ERROR_CODES = {
  SYNC_APARTMENT_NOT_FOUND: 'SYNC_APARTMENT_NOT_FOUND',
  SYNC_ACCESS_DENIED: 'SYNC_ACCESS_DENIED',
  SYNC_VALIDATION_FAILED: 'SYNC_VALIDATION_FAILED',
} as const;

export const SYNC_ERROR_HTTP_MAP: Readonly<Record<string, HttpErrorMappingEntry>> = {
  [SYNC_HTTP_ERROR_CODES.SYNC_APARTMENT_NOT_FOUND]: {
    status: HTTP_STATUS.NOT_FOUND,
    title: 'Apartment Not Found',
  },
  [SYNC_HTTP_ERROR_CODES.SYNC_ACCESS_DENIED]: {
    status: HTTP_STATUS.FORBIDDEN,
    title: 'Sync Access Denied',
  },
  [SYNC_HTTP_ERROR_CODES.SYNC_VALIDATION_FAILED]: {
    status: HTTP_STATUS.UNPROCESSABLE_ENTITY,
    title: 'Invalid Sync Query',
  },
};
