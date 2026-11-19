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
      UuidV7: z.object({
        type: z.literal('string'),
        pattern: z.string(),
      }),
      PresignedUrl: z.record(z.string(), z.unknown()),
      SyncChangePayload: z.record(z.string(), z.unknown()),
      InitMediaUploadResponse: z.object({
        properties: z.object({ upload: z.record(z.string(), z.unknown()) }),
      }),
      HydratedSyncChange: z.object({
        properties: z.object({ payload: z.record(z.string(), z.unknown()) }),
      }),
    }),
  }),
});

function collectPatterns(node: unknown, found: string[]): void {
  if (Array.isArray(node)) {
    for (const item of node) {
      collectPatterns(item, found);
    }
    return;
  }
  if (node === null || typeof node !== 'object') {
    return;
  }
  for (const [key, value] of Object.entries(node)) {
    if (key === 'pattern' && typeof value === 'string') {
      found.push(value);
    } else {
      collectPatterns(value, found);
    }
  }
}

describe('OpenAPI contract (/contracts/openapi.yaml)', () => {
  it('matches the generated OpenAPI YAML on disk with zero drift', async () => {
    const generatedYaml = renderOpenApiYaml();
    const committedYaml = await readFile(CONTRACT_PATH, 'utf8');
    expect(committedYaml).toBe(generatedYaml);

    const reparsed: unknown = parse(committedYaml);
    expect(reparsed).toEqual(buildOpenApiDocument());
  });

  it('exposes unique operationIds, valid ECMA-262 patterns, non-nullable component refs, and complete DomainErrorCode enum', () => {
    const rawDoc = buildOpenApiDocument();
    const doc = openApiSubsetSchema.parse(rawDoc);

    expect(doc.paths['/v1/local-storage/objects']).toBeUndefined();

    const patterns: string[] = [];
    collectPatterns(rawDoc, patterns);
    expect(patterns.length).toBeGreaterThan(0);
    for (const pattern of patterns) {
      expect(pattern).not.toMatch(/\/[a-z]+$/);
      expect(() => new RegExp(pattern)).not.toThrow();
    }
    const uuidRegex = new RegExp(doc.components.schemas.UuidV7.pattern);
    expect(uuidRegex.test('01933e2a-7b40-7000-8000-000000000001')).toBe(true);
    expect(uuidRegex.test('01933E2A-7B40-7000-A000-000000000001')).toBe(true);

    expect(doc.components.schemas.PresignedUrl['nullable']).toBeUndefined();
    expect(doc.components.schemas.SyncChangePayload['nullable']).toBeUndefined();
    expect(doc.components.schemas.InitMediaUploadResponse.properties.upload).toEqual({
      allOf: [{ $ref: '#/components/schemas/PresignedUrl' }],
      nullable: true,
    });
    expect(doc.components.schemas.HydratedSyncChange.properties.payload).toEqual({
      allOf: [{ $ref: '#/components/schemas/SyncChangePayload' }],
      nullable: true,
    });

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
