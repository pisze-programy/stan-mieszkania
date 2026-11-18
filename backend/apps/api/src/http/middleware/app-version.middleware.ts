import {
  APP_VERSION_MAX_LENGTH,
  HEADER_NAMES,
  HTTP_STATUS,
  SEMVER_REGEX,
} from '@stanmieszkania/http-contracts';
import { createDomainError } from '@stanmieszkania/shared';
import { createMiddleware } from 'hono/factory';
import { mapDomainErrorToHttp } from '../domain-error-to-http.mapper';
import {
  COMMON_ERROR_CODES,
  DIGITS_ONLY_REGEX,
  PUBLIC_CONFIG_ROUTE_PATH,
  SEMVER_PART_COUNT,
  SEMVER_RADIX,
} from '../http.constants';
import type { HttpContextVariables } from '../http-env';
import { problemDetailsResponse } from '../problem-details';

interface ParsedSemver {
  readonly core: readonly [number, number, number];
  readonly prerelease: readonly string[];
}

function parseSemver(version: string): ParsedSemver | null {
  if (version.length > APP_VERSION_MAX_LENGTH || !SEMVER_REGEX.test(version)) {
    return null;
  }

  const hyphenIndex = version.indexOf('-');
  const corePart = hyphenIndex === -1 ? version : version.slice(0, hyphenIndex);
  const prereleasePart = hyphenIndex === -1 ? undefined : version.slice(hyphenIndex + 1);
  if (prereleasePart !== undefined && prereleasePart.length === 0) {
    return null;
  }

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
    prerelease: prereleasePart === undefined ? [] : prereleasePart.split('.'),
  };
}

function comparePrereleaseIdentifiers(left: readonly string[], right: readonly string[]): number {
  if (left.length === 0 && right.length === 0) {
    return 0;
  }
  if (left.length === 0) {
    return 1;
  }
  if (right.length === 0) {
    return -1;
  }

  const minLen = Math.min(left.length, right.length);
  for (let index = 0; index < minLen; index += 1) {
    const a = left[index] ?? '';
    const b = right[index] ?? '';
    if (a === b) {
      continue;
    }

    const aIsNum = DIGITS_ONLY_REGEX.test(a);
    const bIsNum = DIGITS_ONLY_REGEX.test(b);
    if (aIsNum && bIsNum) {
      return Number.parseInt(a, SEMVER_RADIX) < Number.parseInt(b, SEMVER_RADIX) ? -1 : 1;
    }
    if (aIsNum !== bIsNum) {
      return aIsNum ? -1 : 1;
    }
    return a < b ? -1 : 1;
  }

  if (left.length === right.length) {
    return 0;
  }
  return left.length < right.length ? -1 : 1;
}

function compareSemver(left: ParsedSemver, right: ParsedSemver): number {
  for (let index = 0; index < SEMVER_PART_COUNT; index += 1) {
    const a = left.core[index] ?? 0;
    const b = right.core[index] ?? 0;
    if (a !== b) {
      return a < b ? -1 : 1;
    }
  }

  return comparePrereleaseIdentifiers(left.prerelease, right.prerelease);
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
