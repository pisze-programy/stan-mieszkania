import path from 'node:path';
import { fileURLToPath } from 'node:url';
import eslint from '@eslint/js';
import { defineConfig, globalIgnores } from 'eslint/config';
import boundaries from 'eslint-plugin-boundaries';
import tseslint from 'typescript-eslint';
import { BOUNDARY_ELEMENTS, BOUNDARY_FILES, BOUNDARY_POLICIES } from './eslint.boundaries';

const MAX_LINES_PER_FILE = 200;
const ALLOWED_MAGIC_NUMBERS: readonly number[] = [-1, 0, 1];
const WORKSPACE_ROOT = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig(
  globalIgnores([
    '**/node_modules/**',
    '**/dist/**',
    '**/coverage/**',
    '**/.wrangler/**',
    '**/.mf/**',
  ]),
  eslint.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: WORKSPACE_ROOT,
      },
    },
    plugins: {
      boundaries,
    },
    settings: {
      'boundaries/root-path': WORKSPACE_ROOT,
      'boundaries/elements': BOUNDARY_ELEMENTS,
      'boundaries/files': BOUNDARY_FILES,
      'import/resolver': {
        typescript: {
          alwaysTryTypes: true,
          project: ['tsconfig.json', 'apps/*/tsconfig.json', 'packages/*/tsconfig.json'],
        },
      },
    },
    rules: {
      'max-lines': [
        'error',
        {
          max: MAX_LINES_PER_FILE,
          skipBlankLines: true,
          skipComments: true,
        },
      ],
      'no-restricted-syntax': [
        'error',
        {
          selector: 'ExportDefaultDeclaration',
          message: 'Default exports are disallowed; use named exports instead.',
        },
      ],
      '@typescript-eslint/no-magic-numbers': [
        'error',
        {
          ignore: [...ALLOWED_MAGIC_NUMBERS],
          ignoreEnums: true,
          ignoreNumericLiteralTypes: true,
          ignoreReadonlyClassProperties: true,
          ignoreTypeIndexes: true,
        },
      ],
      '@typescript-eslint/consistent-type-imports': [
        'error',
        {
          prefer: 'type-imports',
          fixStyle: 'inline-type-imports',
        },
      ],
      'boundaries/dependencies': [
        'error',
        {
          default: 'disallow',
          checkAllOrigins: true,
          policies: BOUNDARY_POLICIES,
        },
      ],
    },
  },
  {
    // Architecture A8: *.constants.ts centralize domain literals; tests assert literal fixtures directly.
    files: ['**/*.constants.ts', '**/*.test.ts'],
    rules: {
      '@typescript-eslint/no-magic-numbers': 'off',
    },
  },
  {
    // Architecture A15: Cloudflare Worker entry and flat tool configs require default exports.
    files: ['apps/api/src/index.ts', '**/*.config.ts', '**/*.config.mjs', '**/*.config.js'],
    rules: {
      'no-restricted-syntax': 'off',
    },
  },
);
