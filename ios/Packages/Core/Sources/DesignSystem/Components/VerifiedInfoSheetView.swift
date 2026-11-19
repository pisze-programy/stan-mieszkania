import SwiftUI

public enum VerifiedInfoSubject: String, Identifiable, Sendable {
  case photo
  case entry

  public var id: String { rawValue }
}

public struct VerifiedInfoSheetView: View {
  private struct InfoRowContent: Identifiable {
    let id: String
    let systemImage: String
    let titleKey: String
    let detailKey: String
  }

  private static let sectionSpacing: CGFloat = 20
  private static let heroIconSize: CGFloat = 44
  private static let rowIconSize: CGFloat = 22
  private static let rowIconColumnWidth: CGFloat = 28
  private static let topPadding: CGFloat = 28

  private let subject: VerifiedInfoSubject

  public init(subject: VerifiedInfoSubject) {
    self.subject = subject
  }

  public var body: some View {
    VStack(spacing: Self.sectionSpacing) {
      Image(systemName: "checkmark.seal.fill")
        .font(.system(size: Self.heroIconSize))
        .foregroundStyle(.green)

      Text(L10n.string(titleKey))
        .font(.title2.bold())
        .multilineTextAlignment(.center)

      VStack(alignment: .leading, spacing: Spacing.md) {
        ForEach(rows) { row in
          infoRow(
            systemImage: row.systemImage,
            title: L10n.string(row.titleKey),
            detail: L10n.string(row.detailKey)
          )
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Text(L10n.string(footerKey))
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(.top, Self.topPadding)
    .padding(.horizontal, Spacing.lg)
    .padding(.bottom, Spacing.lg)
    .frame(maxWidth: .infinity)
    .selfSizingSheet()
  }

  private var titleKey: String {
    switch subject {
    case .photo:
      return "verified.info.title"
    case .entry:
      return "verified.info.entry.title"
    }
  }

  private var footerKey: String {
    switch subject {
    case .photo:
      return "verified.info.footer"
    case .entry:
      return "verified.info.entry.footer"
    }
  }

  private var rows: [InfoRowContent] {
    switch subject {
    case .photo:
      return [
        InfoRowContent(
          id: "cloud",
          systemImage: "lock.icloud",
          titleKey: "verified.info.cloud.title",
          detailKey: "verified.info.cloud.detail"
        ),
        InfoRowContent(
          id: "server",
          systemImage: "clock.badge.checkmark",
          titleKey: "verified.info.server.title",
          detailKey: "verified.info.server.detail"
        ),
        InfoRowContent(
          id: "author",
          systemImage: "person.crop.circle.badge.checkmark",
          titleKey: "verified.info.author.title",
          detailKey: "verified.info.author.detail"
        ),
        InfoRowContent(
          id: "original",
          systemImage: "camera.aperture",
          titleKey: "verified.info.original.title",
          detailKey: "verified.info.original.detail"
        ),
      ]
    case .entry:
      return [
        InfoRowContent(
          id: "cloud",
          systemImage: "lock.icloud",
          titleKey: "verified.info.entry.cloud.title",
          detailKey: "verified.info.entry.cloud.detail"
        ),
        InfoRowContent(
          id: "server",
          systemImage: "clock.badge.checkmark",
          titleKey: "verified.info.entry.server.title",
          detailKey: "verified.info.entry.server.detail"
        ),
        InfoRowContent(
          id: "author",
          systemImage: "person.crop.circle.badge.checkmark",
          titleKey: "verified.info.entry.author.title",
          detailKey: "verified.info.entry.author.detail"
        ),
        InfoRowContent(
          id: "edit",
          systemImage: "pencil.slash",
          titleKey: "verified.info.entry.edit.title",
          detailKey: "verified.info.entry.edit.detail"
        ),
      ]
    }
  }

  private func infoRow(systemImage: String, title: String, detail: String) -> some View {
    HStack(alignment: .top, spacing: Spacing.sm) {
      Image(systemName: systemImage)
        .font(.system(size: Self.rowIconSize))
        .foregroundStyle(.green)
        .frame(width: Self.rowIconColumnWidth, alignment: .center)

      VStack(alignment: .leading, spacing: Spacing.xxs) {
        Text(title)
          .font(.body)
        Text(detail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }
}
