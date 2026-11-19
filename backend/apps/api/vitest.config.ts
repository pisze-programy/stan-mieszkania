import { defineConfig } from 'vitest/config';

const VITEST_TIMEOUT_MS = 30_000;

export default defineConfig({
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
    testTimeout: VITEST_TIMEOUT_MS,
    hookTimeout: VITEST_TIMEOUT_MS,
  },
});
