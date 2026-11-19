export const HTTP_STATUS = {
  OK: 200,
  CREATED: 201,
  NO_CONTENT: 204,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  UNPROCESSABLE_ENTITY: 422,
  UPGRADE_REQUIRED: 426,
  TOO_MANY_REQUESTS: 429,
  INTERNAL_SERVER_ERROR: 500,
  BAD_GATEWAY: 502,
  SERVICE_UNAVAILABLE: 503,
} as const;

export type HttpStatusCode = (typeof HTTP_STATUS)[keyof typeof HTTP_STATUS];

export const HEADER_NAMES = {
  REQUEST_ID: 'X-Request-Id',
  APP_VERSION: 'X-App-Version',
} as const;

export const PROBLEM_JSON_CONTENT_TYPE = 'application/problem+json';
export const PROBLEM_BASE_TYPE_URI = 'https://stanmieszkania.pl/problems/';

export const UUID_V7_SCHEMA_REGEX =
  /^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-7[0-9A-Fa-f]{3}-[89ABab][0-9A-Fa-f]{3}-[0-9A-Fa-f]{12}$/;

export const SEMVER_REGEX = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z-.]+)?$/;
export const APP_VERSION_MIN_LENGTH = 5;
export const APP_VERSION_MAX_LENGTH = 32;

export const MIN_CURSOR_SEQ = 0;
export const MIN_PAGE_LIMIT = 1;
export const MAX_PAGE_LIMIT = 200;
export const DEFAULT_QUERY_PAGE_LIMIT = 100;

export const MIN_HTTP_ERROR_STATUS = 400;
export const MAX_HTTP_ERROR_STATUS = 599;
