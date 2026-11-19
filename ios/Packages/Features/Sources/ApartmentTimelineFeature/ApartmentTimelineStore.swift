import Database
import DesignSystem
import Domain
import Foundation
import SQLiteData

enum ApartmentTimelineStore {
  static func fetchSnapshot(
    apartmentId: String,
    from database: any DatabaseWriter,
    calendar: Calendar,
    timeZone: TimeZone
  ) throws -> ApartmentTimelineSnapshot {
    try database.read { db in
      let apartment =
        try ApartmentRecord
        .where { $0.id.eq(apartmentId) && $0.deletedAt.is(nil) }
        .fetchOne(db)?
        .toDomain()
      let mediaItems = try fetchTimelineItems(apartmentId: apartmentId, in: db)
      let sections = groupSections(items: mediaItems, calendar: calendar, timeZone: timeZone)
      let localUnsyncedCount = mediaItems.count { item in
        item.media.serverReceivedAt == nil
          && item.media.syncState == .localOnly
          && item.media.deletedAt == nil
      }
      // Invariant 6: Cloud quota counts all server-confirmed media including soft-deleted items.
      let confirmedCloudCount = mediaItems.count { $0.media.serverReceivedAt != nil }
      let cloudMediaCount = max(apartment?.cloudMediaCount ?? 0, confirmedCloudCount)

      return ApartmentTimelineSnapshot(
        apartment: apartment,
        sections: sections,
        localUnsyncedCount: localUnsyncedCount,
        cloudMediaCount: cloudMediaCount
      )
    }
  }

  private static func fetchTimelineItems(
    apartmentId: String,
    in db: Database
  ) throws -> [TimelineMediaItem] {
    let memberRecords =
      try MemberRecord
      .where { $0.apartmentId.eq(apartmentId) }
      .fetchAll(db)
    var membersByUserId: [String: MemberRecord] = [:]
    for member in memberRecords {
      membersByUserId[member.userId] = member
    }
    let currentUser =
      try LocalUserRecord
      .where { $0.isCurrentUser.eq(true) }
      .fetchOne(db)?
      .toDomain()
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
