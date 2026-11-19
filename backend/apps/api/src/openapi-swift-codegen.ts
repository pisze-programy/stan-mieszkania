import { parse } from 'yaml';
import { z } from 'zod';
import {
  DEFAULT_CLOUD_MEDIA_QUOTA,
  DEFAULT_JPEG_MAX_BYTES,
  DEFAULT_JPEG_MAX_DIMENSION_PX,
  DEFAULT_JPEG_QUALITY,
  DEFAULT_MIN_SUPPORTED_APP_VERSION,
} from './config/config.constants';
import {
  APARTMENT_CITY_MAX_LENGTH,
  APARTMENT_CITY_MIN_LENGTH,
  APARTMENT_NAME_MAX_LENGTH,
  APARTMENT_NAME_MIN_LENGTH,
  APARTMENT_STREET_MAX_LENGTH,
  APARTMENT_STREET_MIN_LENGTH,
  INVITE_CODE_ALPHABET,
  INVITE_CODE_GROUP_LENGTH,
  INVITE_CODE_RAW_LENGTH,
} from './modules/apartments';
import {
  ENTRY_TEXT_MAX_LENGTH,
  ENTRY_TEXT_MIN_LENGTH,
  MARKER_COORD_MAX,
  MARKER_COORD_MIN,
} from './modules/entries';
import {
  AUTHOR_COLOR_PALETTE,
  DISPLAY_NAME_MAX_LENGTH,
  DISPLAY_NAME_MIN_LENGTH,
} from './modules/identity';
import { SHA256_HEX_LENGTH } from './modules/media';
import {
  renderContractConstantsSwift,
  renderDomainErrorCodeSwift,
} from './openapi-swift-templates';

const stringBoundsSchema = z.object({
  minLength: z.number().int(),
  maxLength: z.number().int(),
});

const numericBoundsSchema = z.object({
  minimum: z.number(),
  maximum: z.number(),
});

const openApiContractsSchema = z.object({
  components: z.object({
    schemas: z.object({
      DomainErrorCode: z.object({
        enum: z.array(z.string().min(1)).min(1),
      }),
      UpdateProfileRequest: z.object({
        properties: z.object({ displayName: stringBoundsSchema }),
      }),
      UpsertApartmentRequest: z.object({
        properties: z.object({
          name: stringBoundsSchema,
          street: stringBoundsSchema,
          city: stringBoundsSchema,
        }),
      }),
      CreateEntryRequest: z.object({
        properties: z.object({ text: stringBoundsSchema }),
      }),
      DraftMarker: z.object({
        properties: z.object({ x: numericBoundsSchema, y: numericBoundsSchema }),
      }),
    }),
  }),
});

export interface GeneratedSwiftDomainFiles {
  readonly contractConstantsSwift: string;
  readonly domainErrorCodeSwift: string;
  readonly domainErrorCodes: readonly string[];
}

function assertMatches(label: string, actual: number, expected: number): number {
  if (actual !== expected) {
    throw new Error(
      `OpenAPI drift on ${label}: expected ${String(expected)}, got ${String(actual)}`,
    );
  }
  return actual;
}

export function generateSwiftDomainFiles(openApiYaml: string): GeneratedSwiftDomainFiles {
  const parsed = openApiContractsSchema.parse(parse(openApiYaml));
  const { schemas } = parsed.components;
  const displayName = schemas.UpdateProfileRequest.properties.displayName;
  const apartment = schemas.UpsertApartmentRequest.properties;
  const entryText = schemas.CreateEntryRequest.properties.text;
  const markerX = schemas.DraftMarker.properties.x;
  const markerY = schemas.DraftMarker.properties.y;
  const domainErrorCodes = [...schemas.DomainErrorCode.enum].sort();

  return {
    contractConstantsSwift: renderContractConstantsSwift({
      displayNameMinLength: assertMatches(
        'displayName.minLength',
        displayName.minLength,
        DISPLAY_NAME_MIN_LENGTH,
      ),
      displayNameMaxLength: assertMatches(
        'displayName.maxLength',
        displayName.maxLength,
        DISPLAY_NAME_MAX_LENGTH,
      ),
      apartmentNameMinLength: assertMatches(
        'apartment.name.minLength',
        apartment.name.minLength,
        APARTMENT_NAME_MIN_LENGTH,
      ),
      apartmentNameMaxLength: assertMatches(
        'apartment.name.maxLength',
        apartment.name.maxLength,
        APARTMENT_NAME_MAX_LENGTH,
      ),
      apartmentStreetMinLength: assertMatches(
        'apartment.street.minLength',
        apartment.street.minLength,
        APARTMENT_STREET_MIN_LENGTH,
      ),
      apartmentStreetMaxLength: assertMatches(
        'apartment.street.maxLength',
        apartment.street.maxLength,
        APARTMENT_STREET_MAX_LENGTH,
      ),
      apartmentCityMinLength: assertMatches(
        'apartment.city.minLength',
        apartment.city.minLength,
        APARTMENT_CITY_MIN_LENGTH,
      ),
      apartmentCityMaxLength: assertMatches(
        'apartment.city.maxLength',
        apartment.city.maxLength,
        APARTMENT_CITY_MAX_LENGTH,
      ),
      inviteCodeRawLength: INVITE_CODE_RAW_LENGTH,
      inviteCodeGroupLength: INVITE_CODE_GROUP_LENGTH,
      inviteCodeAlphabet: INVITE_CODE_ALPHABET,
      entryTextMinLength: assertMatches(
        'entry.text.minLength',
        entryText.minLength,
        ENTRY_TEXT_MIN_LENGTH,
      ),
      entryTextMaxLength: assertMatches(
        'entry.text.maxLength',
        entryText.maxLength,
        ENTRY_TEXT_MAX_LENGTH,
      ),
      markerCoordMin: assertMatches(
        'marker.x.minimum',
        markerX.minimum,
        assertMatches('marker.y.minimum', markerY.minimum, MARKER_COORD_MIN),
      ),
      markerCoordMax: assertMatches(
        'marker.x.maximum',
        markerX.maximum,
        assertMatches('marker.y.maximum', markerY.maximum, MARKER_COORD_MAX),
      ),
      sha256HexLength: SHA256_HEX_LENGTH,
      authorColorPalette: AUTHOR_COLOR_PALETTE,
      defaultCloudMediaQuotaPerApartment: DEFAULT_CLOUD_MEDIA_QUOTA,
      defaultJpegMaxDimensionPx: DEFAULT_JPEG_MAX_DIMENSION_PX,
      defaultJpegQuality: DEFAULT_JPEG_QUALITY,
      defaultJpegMaxBytes: DEFAULT_JPEG_MAX_BYTES,
      defaultMinSupportedAppVersion: DEFAULT_MIN_SUPPORTED_APP_VERSION,
    }),
    domainErrorCodeSwift: renderDomainErrorCodeSwift(domainErrorCodes),
    domainErrorCodes,
  };
}
