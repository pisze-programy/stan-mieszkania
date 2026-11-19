import ComposableArchitecture
import DesignSystem
import SwiftUI

struct CreateApartmentSheetView: View {
  @Bindable var store: StoreOf<ApartmentsListFeature>
  let sheet: ApartmentsListFeature.CreateApartmentSheetState

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField(
            L10n.string("apartments.create.name.label"),
            text: Binding(
              get: { sheet.name },
              set: { store.send(.createNameChanged($0)) }
            )
          )
          TextField(
            L10n.string("apartments.create.street.label"),
            text: Binding(
              get: { sheet.street },
              set: { store.send(.createStreetChanged($0)) }
            )
          )
          TextField(
            L10n.string("apartments.create.city.label"),
            text: Binding(
              get: { sheet.city },
              set: { store.send(.createCityChanged($0)) }
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
      .navigationTitle(L10n.string("apartments.create.sheet.title"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.string("apartments.create.cancel.cta")) {
            store.send(.createSheetDismissed)
          }
          .disabled(sheet.isSaving)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(L10n.string("apartments.create.save.cta")) {
            store.send(.createSubmitted)
          }
          .disabled(sheet.isSaving)
        }
      }
    }
  }
}
