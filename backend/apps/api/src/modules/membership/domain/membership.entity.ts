export type MembershipRole = 'owner' | 'contributor';

export interface Membership {
  readonly apartmentId: string;
  readonly userId: string;
  readonly role: MembershipRole;
  readonly joinedAt: string;
  readonly leftAt: string | null;
}

export interface ApartmentMemberView {
  readonly userId: string;
  readonly displayName: string;
  readonly shortTag: string;
  readonly color: string;
  readonly role: MembershipRole;
  readonly joinedAt: string;
  readonly leftAt: string | null;
}

export interface JoinableApartment {
  readonly id: string;
  readonly ownerId: string;
  readonly name: string;
  readonly street: string;
  readonly city: string;
  readonly inviteCode: string;
  readonly inviteCodeRotatedAt: string | null;
  readonly cloudMediaCount: number;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export function isActiveMembership(membership: { readonly leftAt: string | null }): boolean {
  return membership.leftAt === null;
}
