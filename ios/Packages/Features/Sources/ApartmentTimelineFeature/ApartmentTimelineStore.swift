import Database
import DesignSystem
import Domain
import Foundation
import SQLiteData

enum ApartmentTimelineStore {
  static func fetchSnapshot(
    apartmentId: String,
    from database: any DatabaseWriter,
    now: Date,
    calendar: Calendar,
    timeZone: TimeZone
  ) throws -> ApartmentTimelineSnapshot {
    try database.read { db in
      let apartment =
        try ApartmentRecord
        .where { $0.id.eq(apartmentId) && $0.deletedAt.is(nil) }
        .fetchOne(db)?
        .toDomain()
      let memberRecords =
        try MemberRecord
        .where { $0.apartmentId.eq(apartmentId) }
        .fetchAll(db)
      let currentUser =
        try LocalUserRecord
        .where { $0.isCurrentUser.eq(true) }
        .fetchOne(db)?
        .toDomain()
      let mediaItems = try fetchTimelineItems(
        apartmentId: apartmentId,
        memberRecords: memberRecords,
        currentUser: currentUser,
        in: db
      )
      let sections = groupSections(
        items: mediaItems,
        now: now,
        calendar: calendar,
        timeZone: timeZone
      )
      let localUnsyncedCount = mediaItems.count { item in
        item.media.serverReceivedAt == nil
          && item.media.syncState == .localOnly
          && item.media.deletedAt == nil
      }
      // Invariant 6: Cloud quota counts all server-confirmed media including soft-deleted items.
      let confirmedCloudCount = mediaItems.count { $0.media.serverReceivedAt != nil }
      let cloudMediaCount = max(apartment?.cloudMediaCount ?? 0, confirmedCloudCount)
      let showsAuthor = Set(mediaItems.map(\.media.authorId)).count > 1
      let hasOtherMembers = Self.hasOtherActiveMembers(
        in: memberRecords,
        currentUser: currentUser
      )

      return ApartmentTimelineSnapshot(
        apartment: apartment,
        sections: sections,
        localUnsyncedCount: localUnsyncedCount,
        cloudMediaCount: cloudMediaCount,
        showsAuthor: showsAuthor,
        hasOtherMembers: hasOtherMembers
      )
    }
  }

  private static func hasOtherActiveMembers(
    in memberRecords: [MemberRecord],
    currentUser: UserProfile?
  ) -> Bool {
    let activeMembers = memberRecords.filter { $0.leftAt == nil }
    if let currentUser {
      return activeMembers.contains { $0.userId != currentUser.id }
    }
    return activeMembers.count > 1
  }

  private static func fetchTimelineItems(
    apartmentId: String,
    memberRecords: [MemberRecord],
    currentUser: UserProfile?,
    in db: Database
  ) throws -> [TimelineMediaItem] {
    var membersByUserId: [String: MemberRecord] = [:]
    for member in memberRecords {
      membersByUserId[member.userId] = member
    }
    let mediaRecords =
      try MediaRecord
      .where { $0.apartmentId.eq(apartmentId) }
      .order { $0.capturedAt.desc() }
      .fetchAll(db)

    return
      try mediaRecords
      .sorted { lhs, rhs in
        if lhs.capturedAt != rhs.capturedAt {
          return lhs.capturedAt > rhs.capturedAt
        }
        return lhs.id > rhs.id
      }
      .map { record in
        try makeTimelineItem(
          from: record,
          membersByUserId: membersByUserId,
          currentUser: currentUser
        )
      }
  }

  private static func makeTimelineItem(
    from record: MediaRecord,
    membersByUserId: [String: MemberRecord],
    currentUser: UserProfile?
  ) throws -> TimelineMediaItem {
    if let member = membersByUserId[record.authorId] {
      let summary = try member.toAuthorSummary()
      let media = try record.toDomain(author: summary)
      return TimelineMediaItem(
        media: media,
        authorDisplayName: summary.displayName,
        authorColorHex: summary.color,
        authorRole: summary.role
      )
    }

    if let currentUser, currentUser.id == record.authorId {
      let media = try record.toDomain()
      return TimelineMediaItem(
        media: media,
        authorDisplayName: currentUser.displayName,
        authorColorHex: currentUser.color,
        authorRole: nil
      )
    }

    let media = try record.toDomain()
    return TimelineMediaItem(
      media: media,
      authorDisplayName: L10n.string("media.detail.user.anonymous"),
      authorColorHex: DomainConstants.defaultAuthorColor,
      authorRole: nil
    )
  }

  private static func groupSections(
    items: [TimelineMediaItem],
    now: Date,
    calendar: Calendar,
    timeZone: TimeZone
  ) -> [TimelineDaySection] {
    var groupingCalendar = calendar
    groupingCalendar.timeZone = timeZone
    var groupedItems: [String: [TimelineMediaItem]] = [:]
    var sectionTitles: [String: String] = [:]

    for item in items {
      let dayKey = PolishDateFormatters.dayGroupingKey(
        item.media.capturedAt,
        calendar: groupingCalendar
      )
      groupedItems[dayKey, default: []].append(item)
      if sectionTitles[dayKey] == nil {
        sectionTitles[dayKey] = PolishDateFormatters.formatTimelineDayHeader(
          item.media.capturedAt,
          now: now,
          timeZone: timeZone
        )
      }
    }

    return groupedItems.keys.sorted(by: >).compactMap { dayKey in
      guard let dayItems = groupedItems[dayKey], let title = sectionTitles[dayKey] else {
        return nil
      }
      return TimelineDaySection(dayKey: dayKey, title: title, items: dayItems)
    }
  }
}
