import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

public struct ProfileView: View {
  @Bindable var store: StoreOf<ProfileFeature>

  public init(store: StoreOf<ProfileFeature>) {
    self.store = store
  }

  public var body: some View {
    settingsForm
      .task {
        await store.send(.task).finish()
      }
      .overlay(alignment: .top) {
        if let errorMessage = store.errorMessage {
          ToastBanner(message: errorMessage, style: .error) {
            store.send(.dismissError)
          }
          .padding(.horizontal, Spacing.md)
          .padding(.top, Spacing.xs)
          .transition(.move(edge: .top).combined(with: .opacity))
        }
      }
      .animation(Motion.smooth, value: store.errorMessage)
      .navigationTitle(L10n.string("profile.screen.title"))
      .toolbar {
        if store.isNameDirty {
          ToolbarItem(placement: .confirmationAction) {
            Button(L10n.string("profile.name.save")) {
              store.send(.saveDisplayNameTapped)
            }
            .disabled(store.isSavingName)
          }
        }
      }
      .animation(Motion.fade, value: store.isNameDirty)
      .sheet(isPresented: deleteImpactSheetBinding) {
        DeleteAccountImpactSheetView(
          onContinueTapped: { store.send(.deleteImpactContinueTapped) }
        )
      }
  }

  private var settingsForm: some View {
    Form {
      identityHeaderSection
      displayNameSection
      appearanceSection
      signOutSection
      deleteAccountSection
    }
    .formStyle(.grouped)
  }

  var signOutConfirmationBinding: Binding<Bool> {
    Binding(
      get: { store.isSignOutConfirmationPresented },
      set: { if !$0 { store.send(.signOutConfirmationDismissed) } }
    )
  }

  private var deleteImpactSheetBinding: Binding<Bool> {
    Binding(
      get: { store.isDeleteImpactSheetPresented },
      set: { if !$0 { store.send(.deleteImpactSheetDismissed) } }
    )
  }

  var deleteFinalConfirmationBinding: Binding<Bool> {
    Binding(
      get: { store.isDeleteFinalConfirmationPresented },
      set: { if !$0 { store.send(.deleteFinalConfirmationDismissed) } }
    )
  }
}
