import { err, ok, type IdGenerator, type Result } from '@stanmieszkania/shared';
import {
  computeApartmentChanges,
  type ApartmentChange,
  type ApartmentMetadataValues,
} from './apartment-change.entity';
import {
  APARTMENT_CITY_MAX_LENGTH,
  APARTMENT_CITY_MIN_LENGTH,
  APARTMENT_NAME_MAX_LENGTH,
  APARTMENT_NAME_MIN_LENGTH,
  APARTMENT_STREET_MAX_LENGTH,
  APARTMENT_STREET_MIN_LENGTH,
  INITIAL_CLOUD_MEDIA_COUNT,
} from './apartments.constants';
import { apartmentValidationFailedError, type ApartmentError } from './apartments.errors';

export interface Apartment {
  readonly id: string;
  readonly ownerId: string;
  readonly name: string;
  readonly street: string;
  readonly city: string;
  readonly inviteCode: string;
  readonly inviteCodeRotatedAt: string | null;
  readonly cloudMediaCount: number;
  readonly orphanDeleteAfter: string | null;
  readonly createdAt: string;
  readonly updatedAt: string;
  readonly deletedAt: string | null;
}

export interface CreateApartmentInput {
  readonly id: string;
  readonly ownerId: string;
  readonly name: string;
  readonly street: string;
  readonly city: string;
  readonly inviteCode: string;
  readonly createdAt: string;
}

export interface ApplyApartmentMetadataUpdateInput {
  readonly apartment: Apartment;
  readonly authorId: string;
  readonly name?: string;
  readonly street?: string;
  readonly city?: string;
  readonly updatedAt: string;
  readonly idGenerator: IdGenerator;
}

export interface AppliedApartmentUpdate {
  readonly apartment: Apartment;
  readonly changes: readonly ApartmentChange[];
}

function validateField(
  field: string,
  raw: string,
  minLength: number,
  maxLength: number,
): Result<string, ApartmentError> {
  const trimmed = raw.trim();
  if (trimmed.length < minLength) {
    return err(apartmentValidationFailedError(`Apartment ${field} must not be empty`, { field }));
  }
  if (trimmed.length > maxLength) {
    return err(
      apartmentValidationFailedError(
        `Apartment ${field} must not exceed ${String(maxLength)} characters`,
        { field, maxLength },
      ),
    );
  }
  return ok(trimmed);
}

export function validateApartmentMetadata(
  input: ApartmentMetadataValues,
): Result<ApartmentMetadataValues, ApartmentError> {
  const name = validateField(
    'name',
    input.name,
    APARTMENT_NAME_MIN_LENGTH,
    APARTMENT_NAME_MAX_LENGTH,
  );
  if (!name.ok) {
    return name;
  }

  const street = validateField(
    'street',
    input.street,
    APARTMENT_STREET_MIN_LENGTH,
    APARTMENT_STREET_MAX_LENGTH,
  );
  if (!street.ok) {
    return street;
  }

  const city = validateField(
    'city',
    input.city,
    APARTMENT_CITY_MIN_LENGTH,
    APARTMENT_CITY_MAX_LENGTH,
  );
  if (!city.ok) {
    return city;
  }

  return ok({
    name: name.value,
    street: street.value,
    city: city.value,
  });
}

export function createApartment(input: CreateApartmentInput): Result<Apartment, ApartmentError> {
  const metadata = validateApartmentMetadata({
    name: input.name,
    street: input.street,
    city: input.city,
  });
  if (!metadata.ok) {
    return metadata;
  }

  return ok({
    id: input.id,
    ownerId: input.ownerId,
    name: metadata.value.name,
    street: metadata.value.street,
    city: metadata.value.city,
    inviteCode: input.inviteCode,
    inviteCodeRotatedAt: null,
    cloudMediaCount: INITIAL_CLOUD_MEDIA_COUNT,
    orphanDeleteAfter: null,
    createdAt: input.createdAt,
    updatedAt: input.createdAt,
    deletedAt: null,
  });
}

export function applyApartmentMetadataUpdate(
  input: ApplyApartmentMetadataUpdateInput,
): Result<AppliedApartmentUpdate, ApartmentError> {
  const previous: ApartmentMetadataValues = {
    name: input.apartment.name,
    street: input.apartment.street,
    city: input.apartment.city,
  };

  const validated = validateApartmentMetadata({
    name: input.name ?? previous.name,
    street: input.street ?? previous.street,
    city: input.city ?? previous.city,
  });
  if (!validated.ok) {
    return validated;
  }

  const changes = computeApartmentChanges({
    apartmentId: input.apartment.id,
    authorId: input.authorId,
    previous,
    next: validated.value,
    createdAt: input.updatedAt,
    idGenerator: input.idGenerator,
  });

  if (changes.length === 0) {
    return ok({
      apartment: input.apartment,
      changes,
    });
  }

  return ok({
    apartment: {
      ...input.apartment,
      name: validated.value.name,
      street: validated.value.street,
      city: validated.value.city,
      updatedAt: input.updatedAt,
    },
    changes,
  });
}

export function rotateInviteCode(
  apartment: Apartment,
  newInviteCode: string,
  rotatedAt: string,
): Apartment {
  return {
    ...apartment,
    inviteCode: newInviteCode,
    inviteCodeRotatedAt: rotatedAt,
    updatedAt: rotatedAt,
  };
}

// Decision Q8/Q9: Prompt owner to reset code when a contributor joined after the last rotation.
export function shouldSuggestInviteCodeReset(
  inviteCodeRotatedAt: string | null,
  latestContributorJoinedAt: string | null,
): boolean {
  if (latestContributorJoinedAt === null) {
    return false;
  }
  if (inviteCodeRotatedAt === null) {
    return true;
  }
  return Date.parse(latestContributorJoinedAt) > Date.parse(inviteCodeRotatedAt);
}
