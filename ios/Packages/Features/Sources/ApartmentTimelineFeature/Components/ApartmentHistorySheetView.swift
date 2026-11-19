import DesignSystem
import Domain
import SwiftUI

struct ApartmentHistorySheetView: View {
  let sheet: ApartmentHistorySheetState
  let referenceDate: Date
  let onClose: () -> Void

  var body: some View {
    NavigationStack {
      Group {
        if sheet.changes.isEmpty && sheet.isLoading {
          ProgressView()
        } else if let errorMessage = sheet.errorMessage, sheet.changes.isEmpty {
          ContentUnavailableView(
            L10n.string("apartment.history.sheet.title"),
            systemImage: "exclamationmark.triangle",
            description: Text(errorMessage)
          )
        } else if sheet.changes.isEmpty {
          ContentUnavailableView(
            L10n.string("apartment.history.empty"),
            systemImage: "clock.arrow.circlepath"
          )
        } else {
          List(sheet.changes) { change in
            changeRow(change)
          }
        }
      }
      .navigationTitle(L10n.string("apartment.history.sheet.title"))
      .toolbar {
        if sheet.isLoading && !sheet.changes.isEmpty {
          ToolbarItem(placement: .automatic) {
            ProgressView()
              .controlSize(.small)
          }
        }
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.string("apartment.history.close.cta"), action: onClose)
        }
      }
    }
  }

  private func changeRow(_ change: ApartmentChange) -> some View {
    VStack(alignment: .leading, spacing: Spacing.xxs) {
      HStack {
        Text(fieldLabel(for: change.field))
          .font(Typography.cardTitle)
        Spacer()
        Text(PolishDateFormatters.formatHumanTimestamp(change.createdAt, now: referenceDate))
          .font(Typography.caption)
          .foregroundStyle(.secondary)
      }
      Text("\(change.oldValue) -> \(change.newValue)")
        .font(Typography.callout)
      Text(
        sheet.authorNames[change.authorId]
          ?? L10n.string("media.detail.user.anonymous")
      )
      .font(Typography.caption)
      .foregroundStyle(.secondary)
    }
    .padding(.vertical, Spacing.xxs)
  }

  private func fieldLabel(for field: ApartmentEditableField) -> String {
    switch field {
    case .name:
      L10n.string("apartments.create.name.label")
    case .street:
      L10n.string("apartments.create.street.label")
    case .city:
      L10n.string("apartments.create.city.label")
    }
  }
}
