import type {
  ApartmentMemberView,
  JoinableApartment,
  Membership,
} from '../domain/membership.entity';
import type { ApartmentRow } from '../../apartments';
import type { MemberViewRow } from './memberships.queries';
import type { MembershipRow } from './memberships.table';

export function mapMembershipRowToEntity(row: MembershipRow): Membership {
  return {
    apartmentId: row.apartment_id,
    userId: row.user_id,
    role: row.role,
    joinedAt: row.joined_at,
    leftAt: row.left_at,
  };
}

export function mapMemberViewRowToView(row: MemberViewRow): ApartmentMemberView {
  return {
    userId: row.user_id,
    displayName: row.display_name,
    shortTag: row.short_tag,
    color: row.color,
    role: row.role,
    joinedAt: row.joined_at,
    leftAt: row.left_at,
  };
}

export function mapApartmentRowToJoinable(row: ApartmentRow): JoinableApartment {
  return {
    id: row.id,
    ownerId: row.owner_id,
    name: row.name,
    street: row.street,
    city: row.city,
    inviteCode: row.invite_code,
    inviteCodeRotatedAt: row.invite_code_rotated_at,
    cloudMediaCount: row.cloud_media_count,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
