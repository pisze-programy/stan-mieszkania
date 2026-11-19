import { z } from '@hono/zod-openapi';
import { stringify } from 'yaml';
import { createApp } from './app';
import { COMMON_ERROR_CODES } from './http/http.constants';
import { ACCOUNT_DELETION_ERROR_CODES } from './modules/account-deletion';
import { APARTMENT_ERROR_CODES } from './modules/apartments';
import { ENTRY_ERROR_CODES } from './modules/entries';
import { IDENTITY_ERROR_CODES } from './modules/identity';
import { MEDIA_ERROR_CODES, PresignedUrlDtoSchema } from './modules/media';
import { MEMBERSHIP_ERROR_CODES } from './modules/membership';
import { SYNC_ERROR_CODES, SyncChangePayloadSchema } from './modules/sync';

export const OPENAPI_VERSION = '3.0.3';
export const OPENAPI_API_VERSION = '1.0.0';
const YAML_INDENT_SPACES = 2;
const YAML_LINE_WIDTH = 0;

function collectAllDomainErrorCodes(): readonly [string, ...string[]] {
  const uniqueCodes = Array.from(
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

  const [first, ...rest] = uniqueCodes;
  if (first === undefined) {
    throw new Error('Domain error code registry must not be empty');
  }
  return [first, ...rest];
}

export const ALL_DOMAIN_ERROR_CODES = collectAllDomainErrorCodes();

export const DomainErrorCodeSchema = z.enum(ALL_DOMAIN_ERROR_CODES).openapi('DomainErrorCode', {
  description: 'Machine-readable domain error code returned in ProblemDetails.code',
});

function isPlainRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function isNullableSentinel(value: unknown): boolean {
  if (!isPlainRecord(value)) {
    return false;
  }
  const keys = Object.keys(value);
  return keys.length === 1 && keys[0] === 'nullable' && value['nullable'] === true;
}

// Normalize Zod-to-OpenAPI 3.0.3 nullable sentinels so Apple swift-openapi-generator emits clean Swift Optionals.
function normalizeOpenApi30Node(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => normalizeOpenApi30Node(item));
  }
  if (!isPlainRecord(value)) {
    return value;
  }

  const out: Record<string, unknown> = {};
  for (const [key, entry] of Object.entries(value)) {
    if ((key === 'allOf' || key === 'oneOf') && Array.isArray(entry)) {
      const hasNullableSentinel = entry.some((item) => isNullableSentinel(item));
      const filtered = entry
        .filter((item) => !isNullableSentinel(item))
        .map((item) => normalizeOpenApi30Node(item));
      out[key] = filtered;
      if (hasNullableSentinel) {
        out['nullable'] = true;
      }
      continue;
    }

    if (key === 'additionalProperties' && isNullableSentinel(entry)) {
      out[key] = true;
      continue;
    }

    out[key] = normalizeOpenApi30Node(entry);
  }
  return out;
}

function sortObjectKeys<T>(record: Readonly<Record<string, T>>): Record<string, T> {
  const sorted: Record<string, T> = {};
  for (const key of Object.keys(record).sort()) {
    const value = record[key];
    if (value !== undefined) {
      sorted[key] = value;
    }
  }
  return sorted;
}

export function buildOpenApiDocument(): Record<string, unknown> {
  const app = createApp();

  app.openAPIRegistry.registerComponent('securitySchemes', 'bearerAuth', {
    type: 'http',
    scheme: 'bearer',
    bearerFormat: 'JWT',
    description: 'Firebase ID token (or local dev bearer token in AUTH_MODE=local)',
  });
  app.openAPIRegistry.register('DomainErrorCode', DomainErrorCodeSchema);
  app.openAPIRegistry.register('PresignedUrl', PresignedUrlDtoSchema);
  app.openAPIRegistry.register('SyncChangePayload', SyncChangePayloadSchema);

  const rawDoc = app.getOpenAPIDocument({
    openapi: OPENAPI_VERSION,
    info: {
      title: 'Stan Mieszkania API',
      version: OPENAPI_API_VERSION,
      description: 'Versioned REST API for shared rental apartment inspection timelines.',
    },
    servers: [
      {
        url: 'https://api.stanmieszkania.pl',
        description: 'Production API',
      },
      {
        url: 'http://localhost:8788',
        description: 'Local Wrangler dev server',
      },
    ],
  });

  const sortedPaths = sortObjectKeys(rawDoc.paths);
  const sortedSchemas =
    rawDoc.components?.schemas !== undefined
      ? sortObjectKeys(rawDoc.components.schemas)
      : undefined;

  const assembled = {
    ...rawDoc,
    paths: sortedPaths,
    ...(rawDoc.components !== undefined
      ? {
          components: {
            ...rawDoc.components,
            ...(sortedSchemas !== undefined ? { schemas: sortedSchemas } : {}),
          },
        }
      : {}),
  };

  const normalized = normalizeOpenApi30Node(assembled);
  if (!isPlainRecord(normalized)) {
    throw new Error('Normalized OpenAPI document must be a plain object');
  }
  enforceNullableRefProperty(normalized, 'HydratedSyncChange', 'payload', 'SyncChangePayload');
  return normalized;
}

// Work around zod-to-openapi dropping nullable on registered discriminatedUnion $ref properties.
function enforceNullableRefProperty(
  document: Record<string, unknown>,
  ownerSchemaName: string,
  propertyName: string,
  targetRefName: string,
): void {
  const components = document['components'];
  if (!isPlainRecord(components)) return;
  const schemas = components['schemas'];
  if (!isPlainRecord(schemas)) return;
  const ownerSchema = schemas[ownerSchemaName];
  if (!isPlainRecord(ownerSchema)) return;
  const properties = ownerSchema['properties'];
  if (!isPlainRecord(properties)) return;
  properties[propertyName] = {
    allOf: [{ $ref: `#/components/schemas/${targetRefName}` }],
    nullable: true,
  };
}

export function renderOpenApiYaml(): string {
  return stringify(buildOpenApiDocument(), {
    indent: YAML_INDENT_SPACES,
    lineWidth: YAML_LINE_WIDTH,
  });
}
