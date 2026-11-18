export interface JpegCompressionConfig {
  readonly maxDimensionPx: number;
  readonly quality: number;
  readonly maxBytes: number;
}

export interface PublicAppConfig {
  readonly minSupportedAppVersion: string;
  readonly cloudMediaQuotaPerApartment: number;
  readonly jpegCompression: JpegCompressionConfig;
}
