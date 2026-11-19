import ComposableArchitecture
import DesignSystem
import SwiftUI

struct JoinApartmentSheetView: View {
  @Bindable var store: StoreOf<ApartmentsListFeature>
  let sheet: ApartmentsListFeature.JoinApartmentSheetState
  @FocusState private var isCodeFieldFocused: Bool

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
          .focused($isCodeFieldFocused)
          #if os(iOS)
            .keyboardType(.asciiCapable)
            .textInputAutocapitalization(.characters)
          #endif
          .autocorrectionDisabled()
          .submitLabel(.join)
          .onSubmit {
            if sheet.isCodeValid && !sheet.isJoining {
              store.send(.joinSubmitted)
            }
          }
        } header: {
          Text(L10n.string("sharing.code.label"))
        } footer: {
          Text(L10n.string("apartments.join.code.footer"))
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
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .onAppear {
        isCodeFieldFocused = true
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(role: .cancel) {
            store.send(.joinSheetDismissed)
          }
          .disabled(sheet.isJoining)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(L10n.string("apartments.join.cta"), role: .confirm) {
            store.send(.joinSubmitted)
          }
          .disabled(sheet.isJoining || !sheet.isCodeValid)
        }
      }
    }
    .interactiveDismissDisabled(sheet.hasUnsavedInput)
  }
}
