import ComposableArchitecture
import DesignSystem
import SwiftUI

struct EditApartmentSheetView: View {
  @Bindable var store: StoreOf<ApartmentTimelineFeature>
  let sheet: EditApartmentSheetState

  private var hasUnsavedInput: Bool {
    guard let apartment = store.apartment else {
      return !sheet.name.isEmpty || !sheet.street.isEmpty || !sheet.city.isEmpty
    }
    return sheet.name != apartment.name
      || sheet.street != apartment.street
      || sheet.city != apartment.city
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField(
            L10n.string("apartments.create.name.label"),
            text: Binding(
              get: { sheet.name },
              set: { store.send(.editNameChanged($0)) }
            )
          )
          TextField(
            L10n.string("apartments.create.street.label"),
            text: Binding(
              get: { sheet.street },
              set: { store.send(.editStreetChanged($0)) }
            )
          )
          TextField(
            L10n.string("apartments.create.city.label"),
            text: Binding(
              get: { sheet.city },
              set: { store.send(.editCityChanged($0)) }
            )
          )
        }

        if let errorMessage = sheet.errorMessage {
          Section {
            Text(errorMessage)
              .font(Typography.callout)
              .foregroundStyle(.red)
          }
        }
      }
      .navigationTitle(L10n.string("apartment.edit.sheet.title"))
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(role: .cancel) {
            store.send(.editSheetDismissed)
          }
          .disabled(sheet.isSaving)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(L10n.string("apartment.edit.save.cta"), role: .confirm) {
            store.send(.editSubmitted)
          }
          .disabled(sheet.isSaving || !sheet.isValid)
        }
      }
    }
    .interactiveDismissDisabled(hasUnsavedInput)
  }
}
