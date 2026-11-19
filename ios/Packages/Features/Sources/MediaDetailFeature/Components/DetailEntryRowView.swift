import DesignSystem
import Domain
import SwiftUI

struct DetailEntryRowView: View {
  let item: MediaDetailEntryItem
  let referenceDate: Date
  let selectedMarkerNumber: Int?
  let canEditOrHardDelete: Bool
  let canRetract: Bool
  let onMarkerTapped: (Int) -> Void
  let onVerifiedTap: () -> Void
  let onEditLocal: () -> Void
  let onDeleteOrRetract: () -> Void

  var body: some View {
    SurfaceCard(cornerRadius: CornerRadius.md, padding: Spacing.sm) {
      if let retractedAt = item.entry.retractedAt {
        retractedPlaceholder(retractedAt: retractedAt)
      } else {
        activeEntryContent
      }
    }
  }

  private var activeEntryContent: some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      HStack(spacing: Spacing.xs) {
        AuthorAvatarView(
          displayName: item.authorDisplayName,
          colorHex: item.authorColorHex,
          size: DesignMetrics.entryAuthorAvatarSize
        )
        Text(item.authorDisplayName)
          .font(Typography.subheadline.weight(.semibold))
          .lineLimit(1)
        Spacer()
        if item.entry.isVerified {
          VerifiedBadgeView(style: .inline, onTap: onVerifiedTap)
        }
        actionMenu
      }

      HighlightedEntryTextView(
        text: item.entry.text,
        selectedMarkerNumber: selectedMarkerNumber,
        linkedMarkerNumbers: Set(item.entry.markers.map(\.number)),
        onMarkerTapped: onMarkerTapped
      )
      .frame(maxWidth: .infinity, alignment: .leading)

      Text(PolishDateFormatters.formatHumanTimestamp(item.entry.createdAt, now: referenceDate))
        .font(Typography.caption)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var actionMenu: some View {
    if canEditOrHardDelete || canRetract {
      Menu {
        if canEditOrHardDelete {
          Button(action: onEditLocal) {
            Label(L10n.string("media.detail.entry.edit.cta"), systemImage: "pencil")
          }
          Button(role: .destructive, action: onDeleteOrRetract) {
            Label(L10n.string("apartment.delete.confirm.cta"), systemImage: "trash")
          }
        } else if canRetract {
          Button(role: .destructive, action: onDeleteOrRetract) {
            Label(
              L10n.string("media.detail.entry.retract.cta"),
              systemImage: "arrow.uturn.backward"
            )
          }
        }
      } label: {
        Image(systemName: "ellipsis")
          .foregroundStyle(.secondary)
          .padding(Spacing.xxs)
      }
    }
  }

  private func retractedPlaceholder(retractedAt: Date) -> some View {
    // Decision S2-3: Retracted entries show an audit trail placeholder with author name and timestamp.
    let formattedDate = PolishDateFormatters.formatHumanTimestamp(retractedAt, now: referenceDate)
    return Text(L10n.format("media.detail.entry.retracted", item.authorDisplayName, formattedDate))
      .font(Typography.callout)
      .italic()
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
