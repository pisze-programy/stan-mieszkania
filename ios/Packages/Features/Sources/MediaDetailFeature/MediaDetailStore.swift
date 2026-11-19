import Database
import DesignSystem
import Domain
import Foundation
import SQLiteData

enum MediaDetailStore {
  static func fetchSnapshot(
    mediaId: String,
    from database: any DatabaseWriter
  ) throws -> MediaDetailSnapshot {
    try database.read { db in
      let localUser =
        try LocalUserRecord
        .where { $0.isCurrentUser.eq(true) }
        .fetchOne(db)?
        .toDomain()

      guard let mediaRecord = try MediaRecord.where({ $0.id.eq(mediaId) }).fetchOne(db) else {
        return MediaDetailSnapshot(
          media: nil,
          mediaAuthorName: L10n.string("media.detail.user.anonymous"),
          mediaAuthorColorHex: DomainConstants.defaultAuthorColor,
          entries: [],
          currentUser: localUser.map(makeFallbackAuthorSummary)
        )
      }

      let membersById = try fetchMembersByUserId(apartmentId: mediaRecord.apartmentId, in: db)
      let currentUser = resolveCurrentUser(localUser: localUser, membersById: membersById)
      let mediaAuthor = resolveAuthor(
        userId: mediaRecord.authorId,
        membersById: membersById,
        localUser: localUser
      )
      let media = try mediaRecord.toDomain(author: mediaAuthor.summary)
      let entries = try fetchEntryItems(
        mediaId: mediaId,
        membersById: membersById,
        localUser: localUser,
        in: db
      )

      let activeMembersCount = membersById.values.filter { $0.leftAt == nil }.count
      return MediaDetailSnapshot(
        media: media,
        mediaAuthorName: mediaAuthor.name,
        mediaAuthorColorHex: mediaAuthor.colorHex,
        entries: entries,
        currentUser: currentUser,
        hasOtherMembers: activeMembersCount > 1
      )
    }
  }

  static func validateEntryText(
    _ text: String,
    markers: [DetailDraftMarker]
  ) -> Result<String, DetailValidationFailure> {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolved =
      trimmed.isEmpty && !markers.isEmpty
      ? markers.map { "[\($0.number)]" }.joined(separator: " ")
      : trimmed

    guard
      resolved.count >= ContractConstants.entryTextMinLength,
      resolved.count <= ContractConstants.entryTextMaxLength
    else {
      return .failure(
        DetailValidationFailure(message: L10n.errorMessage(for: .entryValidationFailed))
      )
    }
    return .success(resolved)
  }

  private static func fetchMembersByUserId(
    apartmentId: String,
    in db: Database
  ) throws -> [String: MemberRecord] {
    let memberRecords =
      try MemberRecord
      .where { $0.apartmentId.eq(apartmentId) }
      .fetchAll(db)
    var result: [String: MemberRecord] = [:]
    for member in memberRecords {
      result[member.userId] = member
    }
    return result
  }

  private static func fetchEntryItems(
    mediaId: String,
    membersById: [String: MemberRecord],
    localUser: UserProfile?,
    in db: Database
  ) throws -> [MediaDetailEntryItem] {
    let entryRecords =
      try EntryRecord
      .where { $0.mediaId.eq(mediaId) }
      .order { $0.createdAt.asc() }
      .fetchAll(db)
      .sorted { lhs, rhs in
        if lhs.createdAt != rhs.createdAt {
          return lhs.createdAt < rhs.createdAt
        }
        return lhs.id < rhs.id
      }

    let markerRecords =
      try MarkerRecord
      .where { $0.mediaId.eq(mediaId) }
      .order { $0.number.asc() }
      .fetchAll(db)
    var markersByEntryId: [String: [MarkerPoint]] = [:]
    for marker in markerRecords {
      markersByEntryId[marker.entryId, default: []].append(marker.toDomain())
    }

    return entryRecords.map { record in
      let author = resolveAuthor(
        userId: record.authorId,
        membersById: membersById,
        localUser: localUser
      )
      // Decision S2-3: Retracted entries hide markers from the photo overlay.
      let markers = record.retractedAt == nil ? (markersByEntryId[record.id] ?? []) : []
      let domainEntry = record.toDomain(markers: markers, author: author.summary)
      return MediaDetailEntryItem(
        entry: domainEntry,
        authorDisplayName: author.name,
        authorColorHex: author.colorHex,
        authorRole: author.role
      )
    }
  }

  private static func resolveCurrentUser(
    localUser: UserProfile?,
    membersById: [String: MemberRecord]
  ) -> AuthorSummary? {
    guard let localUser else {
      return nil
    }
    if let member = membersById[localUser.id], let summary = try? member.toAuthorSummary() {
      return summary
    }
    return makeFallbackAuthorSummary(localUser)
  }

  private struct ResolvedAuthor {
    let name: String
    let colorHex: String
    let role: MemberRole?
    let summary: AuthorSummary?
  }

  private static func resolveAuthor(
    userId: String,
    membersById: [String: MemberRecord],
    localUser: UserProfile?
  ) -> ResolvedAuthor {
    if let member = membersById[userId], let summary = try? member.toAuthorSummary() {
      return ResolvedAuthor(
        name: summary.displayName,
        colorHex: summary.color,
        role: summary.role,
        summary: summary
      )
    }
    if let localUser, localUser.id == userId {
      let summary = makeFallbackAuthorSummary(localUser)
      return ResolvedAuthor(
        name: localUser.displayName,
        colorHex: localUser.color,
        role: nil,
        summary: summary
      )
    }
    return ResolvedAuthor(
      name: L10n.string("media.detail.user.anonymous"),
      colorHex: DomainConstants.defaultAuthorColor,
      role: nil,
      summary: nil
    )
  }

  private static func makeFallbackAuthorSummary(_ profile: UserProfile) -> AuthorSummary {
    AuthorSummary(
      userId: profile.id,
      displayName: profile.displayName,
      shortTag: profile.shortTag,
      color: profile.color,
      role: .contributor
    )
  }
}
