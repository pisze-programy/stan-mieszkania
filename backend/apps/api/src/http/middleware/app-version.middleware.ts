import { HEADER_NAMES, HTTP_STATUS, SEMVER_REGEX } from '@stanmieszkania/http-contracts';
import { createDomainError } from '@stanmieszkania/shared';
import { createMiddleware } from 'hono/factory';
import { mapDomainErrorToHttp } from '../domain-error-to-http.mapper';
import {
  COMMON_ERROR_CODES,
  PUBLIC_CONFIG_ROUTE_PATH,
  SEMVER_PART_COUNT,
  SEMVER_RADIX,
  SEMVER_SPLIT_LIMIT,
} from '../http.constants';
import type { HttpContextVariables } from '../http-env';
import { problemDetailsResponse } from '../problem-details';

interface ParsedSemver {
  readonly core: readonly [number, number, number];
  readonly prerelease: string | undefined;
}

function parseSemver(version: string): ParsedSemver | null {
  if (!SEMVER_REGEX.test(version)) {
    return null;
  }

  const [corePart = '', prerelease] = version.split('-', SEMVER_SPLIT_LIMIT);
  const rawSegments = corePart.split('.');
  if (rawSegments.length !== SEMVER_PART_COUNT) {
    return null;
  }

  const [majorRaw = '0', minorRaw = '0', patchRaw = '0'] = rawSegments;
  return {
    core: [
      Number.parseInt(majorRaw, SEMVER_RADIX),
      Number.parseInt(minorRaw, SEMVER_RADIX),
      Number.parseInt(patchRaw, SEMVER_RADIX),
    ],
    prerelease,
  };
}

function compareSemver(left: ParsedSemver, right: ParsedSemver): number {
  for (let index = 0; index < SEMVER_PART_COUNT; index += 1) {
    const a = left.core[index] ?? 0;
    const b = right.core[index] ?? 0;
    if (a !== b) {
      return a < b ? -1 : 1;
    }
  }

  if (left.prerelease === undefined && right.prerelease !== undefined) {
    return 1;
  }
  if (left.prerelease !== undefined && right.prerelease === undefined) {
    return -1;
  }
  if (left.prerelease !== undefined && right.prerelease !== undefined) {
    return left.prerelease.localeCompare(right.prerelease);
  }
  return 0;
}

export function appVersionMiddleware() {
  return createMiddleware<{ Variables: HttpContextVariables }>(async (c, next) => {
    const rawVersion = c.req.header(HEADER_NAMES.APP_VERSION)?.trim();
    if (rawVersion === undefined || rawVersion.length === 0) {
      c.set('appVersion', undefined);
      await next();
      return;
    }

    const parsedClient = parseSemver(rawVersion);
    if (parsedClient === null) {
      const mapped = mapDomainErrorToHttp(
        createDomainError(
          COMMON_ERROR_CODES.VALIDATION_ERROR,
          `Invalid ${HEADER_NAMES.APP_VERSION} header`,
          { header: HEADER_NAMES.APP_VERSION },
        ),
        c.get('requestId'),
      );
      return problemDetailsResponse(c, mapped.status, mapped.problem);
    }

    c.set('appVersion', rawVersion);

    // Architecture A19: /v1/config stays reachable so outdated apps can render the update prompt.
    const isConfigRoute = c.req.method === 'GET' && c.req.path === PUBLIC_CONFIG_ROUTE_PATH;
    if (!isConfigRoute) {
      const minSupported = c.get('appConfig').minSupportedAppVersion;
      const parsedMin = parseSemver(minSupported);
      if (parsedMin !== null && compareSemver(parsedClient, parsedMin) < 0) {
        const mapped = mapDomainErrorToHttp(
          createDomainError(
            COMMON_ERROR_CODES.APP_UPDATE_REQUIRED,
            `App version ${rawVersion} is below minimum supported version ${minSupported}`,
            { minSupportedAppVersion: minSupported },
          ),
          c.get('requestId'),
        );
        return problemDetailsResponse(c, HTTP_STATUS.UPGRADE_REQUIRED, mapped.problem);
      }
    }

    await next();
    return;
  });
}
