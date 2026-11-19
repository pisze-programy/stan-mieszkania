import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

extension ProfileView {
  private static let headerAvatarSize: CGFloat = 60
  private static let headerTextSpacing: CGFloat = 2
  private static let headerVerticalPadding: CGFloat = 6
  private static let savedIndicatorSize: CGFloat = 22

  var identityHeaderSection: some View {
    Section {
      HStack(spacing: Spacing.md) {
        AuthorAvatarView(
          displayName: store.user?.displayName ?? DomainConstants.fallbackUserDisplayPrefix,
          colorHex: store.user?.color ?? DomainConstants.defaultAuthorColor,
          size: Self.headerAvatarSize
        )
        VStack(alignment: .leading, spacing: Self.headerTextSpacing) {
          Text(store.user?.displayName ?? DomainConstants.fallbackUserDisplayPrefix)
            .font(.title3.weight(.semibold))
          if let user = store.user, user.hasCustomDisplayName {
            Text("#\(user.shortTag)")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
      }
      .padding(.vertical, Self.headerVerticalPadding)
    }
  }

  var displayNameSection: some View {
    Section {
      HStack(spacing: Spacing.xs) {
        TextField(
          L10n.string("profile.name.label"),
          text: Binding(
            get: { store.displayNameInput },
            set: { store.send(.displayNameChanged($0)) }
          )
        )
        .submitLabel(.done)
        .onSubmit {
          if store.isNameDirty && !store.isSavingName {
            store.send(.saveDisplayNameTapped)
          }
        }

        StableSlot(minHeight: Self.savedIndicatorSize, alignment: .trailing) {
          if store.showNameSavedFeedback {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(.green)
              .accessibilityLabel(L10n.string("profile.name.saved"))
          }
        }
        .frame(width: Self.savedIndicatorSize)
        .animation(Motion.fade, value: store.showNameSavedFeedback)
      }
    } header: {
      Text(L10n.string("profile.name.label"))
    } footer: {
      Text(L10n.string("profile.name.footer"))
    }
  }

  var appearanceSection: some View {
    Section(L10n.string("profile.theme.section")) {
      Picker(
        L10n.string("profile.theme.picker"),
        selection: Binding(
          get: { store.selectedTheme },
          set: { store.send(.themeChanged($0)) }
        )
      ) {
        Text(L10n.string("profile.theme.system")).tag(AppThemePreference.system)
        Text(L10n.string("profile.theme.light")).tag(AppThemePreference.light)
        Text(L10n.string("profile.theme.dark")).tag(AppThemePreference.dark)
      }
      .pickerStyle(.menu)
    }
  }

  var signOutSection: some View {
    Section {
      Button {
        store.send(.signOutTapped)
      } label: {
        ZStack(alignment: .leading) {
          Text(L10n.string("profile.sign.out"))
            .opacity(store.isSigningOut ? 0 : 1)
          if store.isSigningOut {
            ProgressView()
              .controlSize(.small)
          }
        }
      }
      .disabled(store.isBusy)
      .confirmationDialog(
        L10n.string("profile.sign.out.confirm.title"),
        isPresented: signOutConfirmationBinding,
        titleVisibility: .visible
      ) {
        Button(L10n.string("profile.sign.out"), role: .destructive) {
          store.send(.signOutConfirmed)
        }
        Button(L10n.string("apartments.create.cancel.cta"), role: .cancel) {
          store.send(.signOutConfirmationDismissed)
        }
      } message: {
        Text(L10n.string("profile.sign.out.confirm.message"))
      }
    }
  }

  var deleteAccountSection: some View {
    Section {
      Button(role: .destructive) {
        store.send(.deleteAccountTapped)
      } label: {
        ZStack(alignment: .leading) {
          Text(L10n.string("profile.delete.account"))
            .opacity(store.isDeletingAccount ? 0 : 1)
          if store.isDeletingAccount {
            ProgressView()
              .controlSize(.small)
          }
        }
      }
      .disabled(store.isBusy)
      .confirmationDialog(
        L10n.string("profile.delete.step2.title"),
        isPresented: deleteFinalConfirmationBinding,
        titleVisibility: .visible
      ) {
        Button(L10n.string("profile.delete.step2.confirm"), role: .destructive) {
          store.send(.deleteAccountConfirmed)
        }
        Button(L10n.string("apartments.create.cancel.cta"), role: .cancel) {
          store.send(.deleteFinalConfirmationDismissed)
        }
      } message: {
        Text(L10n.string("profile.delete.step2.message"))
      }
    } footer: {
      Text(L10n.string("profile.delete.footer"))
    }
  }
}
