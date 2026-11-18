import type { IdGenerator } from '@stanmieszkania/shared';
import { APARTMENT_CHANGE_FIELDS } from './apartments.constants';

export type ApartmentChangeField =
  (typeof APARTMENT_CHANGE_FIELDS)[keyof typeof APARTMENT_CHANGE_FIELDS];

export interface ApartmentChange {
  readonly id: string;
  readonly apartmentId: string;
  readonly authorId: string;
  readonly field: ApartmentChangeField;
  readonly oldValue: string;
  readonly newValue: string;
  readonly createdAt: string;
}

export interface ApartmentMetadataValues {
  readonly name: string;
  readonly street: string;
  readonly city: string;
}

export interface ComputeApartmentChangesInput {
  readonly apartmentId: string;
  readonly authorId: string;
  readonly previous: ApartmentMetadataValues;
  readonly next: ApartmentMetadataValues;
  readonly createdAt: string;
  readonly idGenerator: IdGenerator;
}

const ORDERED_FIELDS: readonly ApartmentChangeField[] = [
  APARTMENT_CHANGE_FIELDS.NAME,
  APARTMENT_CHANGE_FIELDS.STREET,
  APARTMENT_CHANGE_FIELDS.CITY,
];

// Decision S2-9: Record each modified metadata field for member-visible audit history.
export function computeApartmentChanges(
  input: ComputeApartmentChangesInput,
): readonly ApartmentChange[] {
  const changes: ApartmentChange[] = [];

  for (const field of ORDERED_FIELDS) {
    const oldValue = input.previous[field];
    const newValue = input.next[field];
    if (oldValue !== newValue) {
      changes.push({
        id: input.idGenerator.nextId(),
        apartmentId: input.apartmentId,
        authorId: input.authorId,
        field,
        oldValue,
        newValue,
        createdAt: input.createdAt,
      });
    }
  }

  return changes;
}
