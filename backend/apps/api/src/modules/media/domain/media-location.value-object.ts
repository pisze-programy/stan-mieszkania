import { err, ok, type Result } from '@stanmieszkania/shared';
import {
  LOCATION_SOURCES,
  MAX_LATITUDE,
  MAX_LONGITUDE,
  MIN_EXCLUSIVE_ACCURACY_METERS,
  MIN_LATITUDE,
  MIN_LONGITUDE,
} from './media.constants';
import { mediaValidationFailedError, type MediaError } from './media.errors';

export type LocationSource = (typeof LOCATION_SOURCES)[number];

export interface MediaLocation {
  readonly lat: number;
  readonly lng: number;
  readonly accuracyM: number | null;
  readonly locationSource: LocationSource | null;
}

export function validateMediaLocation(location: MediaLocation): Result<MediaLocation, MediaError> {
  if (
    !Number.isFinite(location.lat) ||
    location.lat < MIN_LATITUDE ||
    location.lat > MAX_LATITUDE
  ) {
    return err(
      mediaValidationFailedError('Latitude must be within [-90, 90]', { lat: location.lat }),
    );
  }
  if (
    !Number.isFinite(location.lng) ||
    location.lng < MIN_LONGITUDE ||
    location.lng > MAX_LONGITUDE
  ) {
    return err(
      mediaValidationFailedError('Longitude must be within [-180, 180]', { lng: location.lng }),
    );
  }
  if (
    location.accuracyM !== null &&
    (!Number.isFinite(location.accuracyM) || location.accuracyM <= MIN_EXCLUSIVE_ACCURACY_METERS)
  ) {
    return err(
      mediaValidationFailedError('Location accuracyM must be positive', {
        accuracyM: location.accuracyM,
      }),
    );
  }
  if (location.locationSource !== null && !LOCATION_SOURCES.includes(location.locationSource)) {
    return err(
      mediaValidationFailedError('Unsupported location source', {
        locationSource: location.locationSource,
      }),
    );
  }
  return ok(location);
}
