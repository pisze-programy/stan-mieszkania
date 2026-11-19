export const PRODUCTION_D1_DATABASE_NAME = 'stanmieszkania-production';
export const PRODUCTION_WRANGLER_ENV = 'production';
export const DEPLOY_BOOKMARKS_DIR_NAME = '.deploy-bookmarks';
export const JSON_INDENT_SPACES = 2;
export const CLI_ARGS_START_INDEX = 2;

export const DESTRUCTIVE_SQL_PATTERNS = [
  { label: 'DROP TABLE', regex: /\bDROP\s+TABLE\b/i },
  { label: 'DROP COLUMN', regex: /\bDROP\s+COLUMN\b/i },
  { label: 'TRUNCATE', regex: /\bTRUNCATE\b/i },
] as const;

export const DEPLOY_STEP_NAMES = {
  FORMAT_CHECK: 'format:check',
  TYPECHECK: 'typecheck',
  LINT: 'lint',
  TEST: 'test',
  MIGRATION_SAFETY_CHECK: 'migrations:additive-check',
  TIME_TRAVEL_BOOKMARK: 'd1:time-travel-bookmark',
  D1_MIGRATIONS_APPLY: 'd1:migrations-apply',
  WORKER_DEPLOY: 'worker:deploy',
} as const;
