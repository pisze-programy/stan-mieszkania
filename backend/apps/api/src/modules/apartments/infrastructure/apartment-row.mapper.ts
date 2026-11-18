import type { ApartmentChange } from '../domain/apartment-change.entity';
import type { Apartment } from '../domain/apartment.entity';
import type { ApartmentChangeRow } from './apartment-changes.table';
import type { ApartmentRow } from './apartments.table';

export function mapApartmentRowToEntity(row: ApartmentRow): Apartment {
  return {
    id: row.id,
    ownerId: row.owner_id,
    name: row.name,
    street: row.street,
    city: row.city,
    inviteCode: row.invite_code,
    inviteCodeRotatedAt: row.invite_code_rotated_at,
    cloudMediaCount: row.cloud_media_count,
    orphanDeleteAfter: row.orphan_delete_after,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    deletedAt: row.deleted_at,
  };
}

export function mapApartmentEntityToRow(apartment: Apartment): ApartmentRow {
  return {
    id: apartment.id,
    owner_id: apartment.ownerId,
    name: apartment.name,
    street: apartment.street,
    city: apartment.city,
    invite_code: apartment.inviteCode,
    invite_code_rotated_at: apartment.inviteCodeRotatedAt,
    cloud_media_count: apartment.cloudMediaCount,
    orphan_delete_after: apartment.orphanDeleteAfter,
    created_at: apartment.createdAt,
    updated_at: apartment.updatedAt,
    deleted_at: apartment.deletedAt,
  };
}

export function mapApartmentChangeRowToEntity(row: ApartmentChangeRow): ApartmentChange {
  return {
    id: row.id,
    apartmentId: row.apartment_id,
    authorId: row.author_id,
    field: row.field,
    oldValue: row.old_value,
    newValue: row.new_value,
    createdAt: row.created_at,
  };
}

export function mapApartmentChangeEntityToRow(change: ApartmentChange): ApartmentChangeRow {
  return {
    id: change.id,
    apartment_id: change.apartmentId,
    author_id: change.authorId,
    field: change.field,
    old_value: change.oldValue,
    new_value: change.newValue,
    created_at: change.createdAt,
  };
}
