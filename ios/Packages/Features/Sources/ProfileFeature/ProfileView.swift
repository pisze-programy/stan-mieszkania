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
      .confirmationSheet(
        isPresented: signOutConfirmationBinding,
        isConfirming: store.isSigningOut,
        content: { store.signOutConfirmationContent },
        onConfirm: { store.send(.signOutConfirmed) }
      )
      .sheet(isPresented: deleteAccountSheetBinding) {
        if let step = store.deleteAccountStep {
          DeleteAccountImpactSheetView(
            step: step,
            isDeleting: store.isDeletingAccount,
            onContinue: { store.send(.deleteImpactContinueTapped) },
            onConfirm: { store.send(.deleteAccountConfirmed) },
            onCancel: { store.send(.deleteAccountSheetDismissed) }
          )
        }
      }
  }

  private var settingsForm: some View {
    Form {
      avatarHeaderSection
      displayNameSection
      appearanceSection
      signOutSection
      deleteAccountSection
    }
    .formStyle(.grouped)
  }

  private var signOutConfirmationBinding: Binding<Bool> {
    Binding(
      get: { store.isSignOutConfirmationPresented },
      set: { if !$0 { store.send(.signOutConfirmationDismissed) } }
    )
  }

  private var deleteAccountSheetBinding: Binding<Bool> {
    Binding(
      get: { store.deleteAccountStep != nil },
      set: { if !$0 { store.send(.deleteAccountSheetDismissed) } }
    )
  }
}
