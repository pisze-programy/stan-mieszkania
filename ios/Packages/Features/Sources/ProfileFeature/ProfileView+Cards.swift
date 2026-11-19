import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

extension ProfileView {
  private static let heroAvatarSize: CGFloat = 88
  private static let savedIndicatorSize: CGFloat = 22

  var avatarHeaderSection: some View {
    let fallbackName = store.user?.displayName ?? DomainConstants.fallbackUserDisplayPrefix
    let previewName = store.displayNameInput.isEmpty ? fallbackName : store.displayNameInput
    return Section {
      AuthorAvatarView(
        displayName: previewName,
        colorHex: store.user?.color ?? DomainConstants.defaultAuthorColor,
        size: Self.heroAvatarSize
      )
      .frame(maxWidth: .infinity)
      .padding(.top, Spacing.sm)
    }
    .listRowBackground(Color.clear)
    .listRowInsets(EdgeInsets())
  }

  var displayNameSection: some View {
    Section {
      HStack(spacing: Spacing.xs) {
        Color.clear
          .frame(width: Self.savedIndicatorSize, height: 1)

        TextField(
          "",
          text: Binding(
            get: { store.displayNameInput },
            set: { store.send(.displayNameChanged($0)) }
          ),
          prompt: Text(L10n.string("profile.name.label"))
        )
        .multilineTextAlignment(.center)
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
    } footer: {
      Text(L10n.string("profile.delete.footer"))
    }
  }
}
