import { z } from '@hono/zod-openapi';
import { SEMVER_REGEX } from '@stanmieszkania/http-contracts';
import {
  MAX_JPEG_QUALITY,
  MIN_CLOUD_MEDIA_QUOTA,
  MIN_JPEG_MAX_BYTES,
  MIN_JPEG_MAX_DIMENSION_PX,
  MIN_JPEG_QUALITY,
} from '../../../config/config.constants';

export const JpegCompressionConfigSchema = z
  .object({
    maxDimensionPx: z.number().int().min(MIN_JPEG_MAX_DIMENSION_PX),
    quality: z.number().min(MIN_JPEG_QUALITY).max(MAX_JPEG_QUALITY),
    maxBytes: z.number().int().min(MIN_JPEG_MAX_BYTES),
  })
  .openapi('JpegCompressionConfig');

export const PublicAppConfigSchema = z
  .object({
    minSupportedAppVersion: z.string().regex(SEMVER_REGEX),
    cloudMediaQuotaPerApartment: z.number().int().min(MIN_CLOUD_MEDIA_QUOTA),
    jpegCompression: JpegCompressionConfigSchema,
  })
  .openapi('PublicAppConfig');
