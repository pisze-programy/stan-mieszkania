import type {
  DependenciesPolicy,
  ElementDescriptors,
  FileDescriptors,
} from 'eslint-plugin-boundaries';

export const LAYER_TYPES = {
  DOMAIN: 'domain',
  APPLICATION: 'application',
  INFRASTRUCTURE: 'infrastructure',
  HTTP: 'http',
  MODULE_TESTING: 'module-testing',
  MODULE_ENTRY: 'module-entry',
  APP_COMPOSITION: 'app-composition',
  APP_CONFIG: 'app-config',
  APP_HTTP: 'app-http',
  APP_DURABLE_OBJECTS: 'app-durable-objects',
  APP_ENTRY: 'app-entry',
  APP_SCRIPTS: 'app-scripts',
  ROOT_SCRIPTS: 'root-scripts',
  PACKAGE_SHARED: 'package-shared',
  PACKAGE_D1: 'package-d1',
  PACKAGE_HTTP_CONTRACTS: 'package-http-contracts',
  PACKAGE_TESTING: 'package-testing',
} as const;

export const FILE_CATEGORIES = {
  TEST: 'test',
  MODULE_PUBLIC_INDEX: 'module-public-index',
} as const;

const SAME_MODULE = { module: '{{ from.element.captured.module }}' };

const CORE_PACKAGES = [
  LAYER_TYPES.PACKAGE_SHARED,
  LAYER_TYPES.PACKAGE_D1,
  LAYER_TYPES.PACKAGE_HTTP_CONTRACTS,
];

const APP_RUNTIME_LAYERS = [
  LAYER_TYPES.APP_COMPOSITION,
  LAYER_TYPES.APP_CONFIG,
  LAYER_TYPES.APP_HTTP,
  LAYER_TYPES.APP_DURABLE_OBJECTS,
  LAYER_TYPES.APP_ENTRY,
];

const MODULE_INTERNAL_LAYERS = [
  LAYER_TYPES.DOMAIN,
  LAYER_TYPES.APPLICATION,
  LAYER_TYPES.INFRASTRUCTURE,
  LAYER_TYPES.HTTP,
  LAYER_TYPES.MODULE_TESTING,
];

const APP_ORCHESTRATORS = [
  LAYER_TYPES.APP_COMPOSITION,
  LAYER_TYPES.APP_DURABLE_OBJECTS,
  LAYER_TYPES.APP_ENTRY,
  LAYER_TYPES.APP_SCRIPTS,
];

const moduleElement = (type: string, layer: string): ElementDescriptors[number] => ({
  type,
  pattern: `apps/api/src/modules/*/${layer}`,
  capture: ['module'],
  partialMatch: false,
});

const rootElement = (type: string, pattern: string): ElementDescriptors[number] => ({
  type,
  pattern,
  partialMatch: false,
});

const allowElements = (from: string | string[], to: string | string[]): DependenciesPolicy => ({
  from: { element: { type: from } },
  allow: { to: { element: { type: to } } },
});

const allowSameModule = (from: string | string[], to: string | string[]): DependenciesPolicy => ({
  from: { element: { type: from } },
  allow: { to: { element: { type: to, captured: SAME_MODULE } } },
});

const allowModuleIndex = (from: string | string[]): DependenciesPolicy => ({
  from: { element: { type: from } },
  allow: {
    to: {
      element: { type: LAYER_TYPES.MODULE_ENTRY },
      file: { categories: [FILE_CATEGORIES.MODULE_PUBLIC_INDEX] },
    },
  },
});

const allowExternalAndCore = (from: string | string[]): DependenciesPolicy => ({
  from: { element: { type: from } },
  allow: { to: { module: { origin: ['external', 'core'] } } },
});

export const BOUNDARY_ELEMENTS: ElementDescriptors = [
  moduleElement(LAYER_TYPES.DOMAIN, 'domain'),
  moduleElement(LAYER_TYPES.APPLICATION, 'application'),
  moduleElement(LAYER_TYPES.INFRASTRUCTURE, 'infrastructure'),
  moduleElement(LAYER_TYPES.HTTP, 'http'),
  moduleElement(LAYER_TYPES.MODULE_TESTING, 'testing'),
  {
    type: LAYER_TYPES.MODULE_ENTRY,
    pattern: 'apps/api/src/modules/*',
    capture: ['module'],
    partialMatch: false,
  },
  rootElement(LAYER_TYPES.APP_COMPOSITION, 'apps/api/src/composition'),
  rootElement(LAYER_TYPES.APP_CONFIG, 'apps/api/src/config'),
  rootElement(LAYER_TYPES.APP_HTTP, 'apps/api/src/http'),
  rootElement(LAYER_TYPES.APP_DURABLE_OBJECTS, 'apps/api/src/durable-objects'),
  rootElement(LAYER_TYPES.APP_ENTRY, 'apps/api/src'),
  rootElement(LAYER_TYPES.APP_SCRIPTS, 'apps/api/scripts'),
  rootElement(LAYER_TYPES.ROOT_SCRIPTS, 'scripts'),
  rootElement(LAYER_TYPES.PACKAGE_SHARED, 'packages/shared'),
  rootElement(LAYER_TYPES.PACKAGE_D1, 'packages/d1'),
  rootElement(LAYER_TYPES.PACKAGE_HTTP_CONTRACTS, 'packages/http-contracts'),
  rootElement(LAYER_TYPES.PACKAGE_TESTING, 'packages/testing'),
];

export const BOUNDARY_FILES: FileDescriptors = [
  { pattern: '**/*.test.ts', category: FILE_CATEGORIES.TEST },
  { pattern: 'apps/api/src/modules/*/index.ts', category: FILE_CATEGORIES.MODULE_PUBLIC_INDEX },
];

export const BOUNDARY_POLICIES: DependenciesPolicy[] = [
  allowElements(LAYER_TYPES.PACKAGE_SHARED, LAYER_TYPES.PACKAGE_SHARED),
  allowElements([LAYER_TYPES.PACKAGE_D1, LAYER_TYPES.PACKAGE_HTTP_CONTRACTS], CORE_PACKAGES),
  allowElements(LAYER_TYPES.PACKAGE_TESTING, [...CORE_PACKAGES, LAYER_TYPES.PACKAGE_TESTING]),
  allowElements(LAYER_TYPES.DOMAIN, LAYER_TYPES.PACKAGE_SHARED),
  allowSameModule(LAYER_TYPES.DOMAIN, LAYER_TYPES.DOMAIN),
  allowElements(LAYER_TYPES.APPLICATION, LAYER_TYPES.PACKAGE_SHARED),
  allowSameModule(LAYER_TYPES.APPLICATION, [LAYER_TYPES.DOMAIN, LAYER_TYPES.APPLICATION]),
  allowModuleIndex(LAYER_TYPES.APPLICATION),
  allowElements(LAYER_TYPES.INFRASTRUCTURE, [...CORE_PACKAGES, LAYER_TYPES.APP_CONFIG]),
  allowSameModule(LAYER_TYPES.INFRASTRUCTURE, [
    LAYER_TYPES.DOMAIN,
    LAYER_TYPES.APPLICATION,
    LAYER_TYPES.INFRASTRUCTURE,
  ]),
  allowModuleIndex(LAYER_TYPES.INFRASTRUCTURE),
  allowElements(LAYER_TYPES.HTTP, [...CORE_PACKAGES, LAYER_TYPES.APP_CONFIG, LAYER_TYPES.APP_HTTP]),
  allowSameModule(LAYER_TYPES.HTTP, [
    LAYER_TYPES.DOMAIN,
    LAYER_TYPES.APPLICATION,
    LAYER_TYPES.HTTP,
  ]),
  allowModuleIndex(LAYER_TYPES.HTTP),
  allowSameModule(LAYER_TYPES.MODULE_ENTRY, MODULE_INTERNAL_LAYERS),
  allowElements(LAYER_TYPES.MODULE_ENTRY, CORE_PACKAGES),
  allowElements(LAYER_TYPES.MODULE_TESTING, [...CORE_PACKAGES, LAYER_TYPES.PACKAGE_TESTING]),
  allowSameModule(LAYER_TYPES.MODULE_TESTING, MODULE_INTERNAL_LAYERS),
  allowElements(LAYER_TYPES.APP_CONFIG, [LAYER_TYPES.APP_CONFIG, ...CORE_PACKAGES]),
  allowElements(LAYER_TYPES.APP_HTTP, [
    LAYER_TYPES.APP_HTTP,
    LAYER_TYPES.APP_CONFIG,
    ...CORE_PACKAGES,
  ]),
  allowElements(APP_ORCHESTRATORS, [...APP_RUNTIME_LAYERS, ...CORE_PACKAGES]),
  allowModuleIndex(APP_ORCHESTRATORS),
  allowElements(LAYER_TYPES.ROOT_SCRIPTS, [LAYER_TYPES.ROOT_SCRIPTS, ...CORE_PACKAGES]),
  // Architecture A6/3.5: domain, application, and packages/shared stay pure (no external/core imports).
  allowExternalAndCore([
    LAYER_TYPES.PACKAGE_D1,
    LAYER_TYPES.PACKAGE_HTTP_CONTRACTS,
    LAYER_TYPES.PACKAGE_TESTING,
    LAYER_TYPES.INFRASTRUCTURE,
    LAYER_TYPES.HTTP,
    LAYER_TYPES.MODULE_ENTRY,
    LAYER_TYPES.MODULE_TESTING,
    ...APP_RUNTIME_LAYERS,
    LAYER_TYPES.APP_SCRIPTS,
    LAYER_TYPES.ROOT_SCRIPTS,
  ]),
  {
    from: { file: { categories: [FILE_CATEGORIES.TEST] } },
    allow: { to: { module: { origin: ['external', 'core'] } } },
  },
  {
    from: { file: { categories: [FILE_CATEGORIES.TEST] } },
    allow: {
      to: {
        element: {
          type: [
            ...CORE_PACKAGES,
            LAYER_TYPES.PACKAGE_TESTING,
            ...APP_RUNTIME_LAYERS,
            ...MODULE_INTERNAL_LAYERS,
            LAYER_TYPES.MODULE_ENTRY,
          ],
        },
      },
    },
  },
];
