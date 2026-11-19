import ComposableArchitecture
import DesignSystem
import SwiftUI

struct JoinApartmentSheetView: View {
  @Bindable var store: StoreOf<ApartmentsListFeature>
  let sheet: ApartmentsListFeature.JoinApartmentSheetState

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField(
            L10n.string("apartments.join.code.prompt"),
            text: Binding(
              get: { sheet.inviteCode },
              set: { store.send(.joinCodeChanged($0)) }
            )
          )
          .font(Typography.monospacedCode)
          #if os(iOS)
            .textInputAutocapitalization(.characters)
          #endif
          .autocorrectionDisabled()
        }

        if let errorMessage = sheet.errorMessage {
          Section {
            Text(errorMessage)
              .font(Typography.callout)
              .foregroundStyle(.red)
          }
        }
      }
      .navigationTitle(L10n.string("apartments.join.sheet.title"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.string("apartments.create.cancel.cta")) {
            store.send(.joinSheetDismissed)
          }
          .disabled(sheet.isJoining)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(L10n.string("apartments.join.cta")) {
            store.send(.joinSubmitted)
          }
          .disabled(sheet.isJoining)
        }
      }
    }
  }
}
