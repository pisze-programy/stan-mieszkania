import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { parse } from 'yaml';
import { z } from 'zod';
import { COMMON_ERROR_CODES } from '../http/http.constants';
import { ACCOUNT_DELETION_ERROR_CODES } from '../modules/account-deletion';
import { APARTMENT_ERROR_CODES } from '../modules/apartments';
import { ENTRY_ERROR_CODES } from '../modules/entries';
import { IDENTITY_ERROR_CODES } from '../modules/identity';
import { MEDIA_ERROR_CODES } from '../modules/media';
import { MEMBERSHIP_ERROR_CODES } from '../modules/membership';
import { SYNC_ERROR_CODES } from '../modules/sync';
import {
  ALL_DOMAIN_ERROR_CODES,
  OPENAPI_VERSION,
  buildOpenApiDocument,
  renderOpenApiYaml,
} from '../openapi';

const TEST_DIR = path.dirname(fileURLToPath(import.meta.url));
const CONTRACT_PATH = path.resolve(TEST_DIR, '../../../../../contracts/openapi.yaml');
const HTTP_METHODS = ['get', 'post', 'put', 'patch', 'delete'] as const;

const operationSchema = z.object({
  operationId: z.string().min(1),
  tags: z.array(z.string().min(1)).min(1),
  security: z.array(z.record(z.string(), z.array(z.string()))).optional(),
});

const openApiSubsetSchema = z.object({
  openapi: z.literal(OPENAPI_VERSION),
  paths: z.record(z.string(), z.record(z.string(), z.unknown())),
  components: z.object({
    securitySchemes: z.object({
      bearerAuth: z.object({
        type: z.literal('http'),
        scheme: z.literal('bearer'),
      }),
    }),
    schemas: z.object({
      DomainErrorCode: z.object({
        type: z.literal('string'),
        enum: z.array(z.string()),
      }),
      ProblemDetails: z.record(z.string(), z.unknown()),
    }),
  }),
});

describe('OpenAPI contract (/contracts/openapi.yaml)', () => {
  it('matches the generated OpenAPI YAML on disk with zero drift', async () => {
    const generatedYaml = renderOpenApiYaml();
    const committedYaml = await readFile(CONTRACT_PATH, 'utf8');
    expect(committedYaml).toBe(generatedYaml);

    const reparsed: unknown = parse(committedYaml);
    expect(reparsed).toEqual(buildOpenApiDocument());
  });

  it('exposes unique operationIds, bearer security on non-public routes, complete DomainErrorCode enum, and excludes local storage', () => {
    const doc = openApiSubsetSchema.parse(buildOpenApiDocument());

    expect(doc.paths['/v1/local-storage/objects']).toBeUndefined();

    const operationIds: string[] = [];
    for (const [routePath, pathItem] of Object.entries(doc.paths)) {
      for (const method of HTTP_METHODS) {
        const rawOperation = pathItem[method];
        if (rawOperation === undefined) {
          continue;
        }
        const operation = operationSchema.parse(rawOperation);
        operationIds.push(operation.operationId);

        if (routePath === '/v1/config') {
          expect(operation.security).toBeUndefined();
        } else {
          expect(operation.security).toEqual([{ bearerAuth: [] }]);
        }
      }
    }

    expect(operationIds).toHaveLength(26);
    expect(new Set(operationIds).size).toBe(operationIds.length);

    const expectedErrorCodes = Array.from(
      new Set<string>([
        ...Object.values(COMMON_ERROR_CODES),
        ...Object.values(IDENTITY_ERROR_CODES),
        ...Object.values(APARTMENT_ERROR_CODES),
        ...Object.values(MEMBERSHIP_ERROR_CODES),
        ...Object.values(ACCOUNT_DELETION_ERROR_CODES),
        ...Object.values(MEDIA_ERROR_CODES),
        ...Object.values(ENTRY_ERROR_CODES),
        ...Object.values(SYNC_ERROR_CODES),
      ]),
    ).sort();

    expect(doc.components.schemas.DomainErrorCode.enum).toEqual(expectedErrorCodes);
    expect(ALL_DOMAIN_ERROR_CODES).toEqual(expectedErrorCodes);
  });
});
