export const FULLSTACK_TIMEOUTS_MS = {
  SERVER_STARTUP: 30_000,
  SERVER_SHUTDOWN: 10_000,
} as const;

export const LIVE_SERVER_READY_PREFIX = 'LIVE_WORKER_BASE_URL=';
export const LIVE_WORKER_ENV_VAR = 'LIVE_WORKER_BASE_URL';

export const IOS_TOOL_PATHS = {
  SWIFT: '/usr/bin/swift',
  XCRUN: '/usr/bin/xcrun',
  SWIFTLINT: '/opt/homebrew/bin/swiftlint',
  XCODEBUILD: '/usr/bin/xcodebuild',
} as const;

export const IOS_SIMULATOR_DESTINATION = 'platform=iOS Simulator,name=iPhone 17,OS=26.5';
export const TEMP_DERIVED_DATA_PATH = '/tmp/sm-fullstack-dd';
export const EXIT_CODE_FAILURE = 1;
