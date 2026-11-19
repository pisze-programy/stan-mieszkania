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
    scrollContent
      .task {
        await store.send(.task).finish()
      }
      .navigationTitle(L10n.string("profile.screen.title"))
      .confirmationDialog(
        L10n.string("profile.sign.out.confirm.title"),
        isPresented: signOutConfirmationBinding,
        titleVisibility: .visible,
        actions: signOutDialogActions,
        message: { Text(L10n.string("profile.sign.out.confirm.message")) }
      )
      .sheet(isPresented: deleteImpactSheetBinding) {
        DeleteAccountImpactSheetView(
          onContinueTapped: { store.send(.deleteImpactContinueTapped) },
          onCancelTapped: { store.send(.deleteImpactSheetDismissed) }
        )
      }
      .confirmationDialog(
        L10n.string("profile.delete.step2.title"),
        isPresented: deleteFinalConfirmationBinding,
        titleVisibility: .visible,
        actions: deleteAccountDialogActions,
        message: { Text(L10n.string("profile.delete.step2.message")) }
      )
  }

  @ViewBuilder
  private func signOutDialogActions() -> some View {
    Button(L10n.string("profile.sign.out"), role: .destructive) {
      store.send(.signOutConfirmed)
    }
    Button(L10n.string("apartments.create.cancel.cta"), role: .cancel) {
      store.send(.signOutConfirmationDismissed)
    }
  }

  @ViewBuilder
  private func deleteAccountDialogActions() -> some View {
    Button(L10n.string("profile.delete.step2.confirm"), role: .destructive) {
      store.send(.deleteAccountConfirmed)
    }
    Button(L10n.string("apartments.create.cancel.cta"), role: .cancel) {
      store.send(.deleteFinalConfirmationDismissed)
    }
  }

  private var scrollContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Spacing.md) {
        if let errorMessage = store.errorMessage {
          errorBanner(errorMessage)
        }

        identityHeaderCard
        displayNameCard
        themePickerCard
        accountActionsCard
      }
      .padding(Spacing.md)
    }
  }

  private var signOutConfirmationBinding: Binding<Bool> {
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

  private var deleteFinalConfirmationBinding: Binding<Bool> {
    Binding(
      get: { store.isDeleteFinalConfirmationPresented },
      set: { if !$0 { store.send(.deleteFinalConfirmationDismissed) } }
    )
  }
}
