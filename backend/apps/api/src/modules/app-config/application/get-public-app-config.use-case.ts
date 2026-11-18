import type { PublicAppConfig } from '../domain/public-app-config';

export interface GetPublicAppConfigInput {
  readonly minSupportedAppVersion: string;
  readonly cloudMediaQuotaPerApartment: number;
  readonly jpegMaxDimensionPx: number;
  readonly jpegQuality: number;
  readonly jpegMaxBytes: number;
}

export interface GetPublicAppConfigUseCase {
  execute(): PublicAppConfig;
}

export function createGetPublicAppConfigUseCase(
  config: GetPublicAppConfigInput,
): GetPublicAppConfigUseCase {
  return {
    execute: () => ({
      minSupportedAppVersion: config.minSupportedAppVersion,
      cloudMediaQuotaPerApartment: config.cloudMediaQuotaPerApartment,
      jpegCompression: {
        maxDimensionPx: config.jpegMaxDimensionPx,
        quality: config.jpegQuality,
        maxBytes: config.jpegMaxBytes,
      },
    }),
  };
}
