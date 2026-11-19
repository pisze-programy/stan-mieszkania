import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

extension ProfileView {
  var identityHeaderCard: some View {
    GlassCard(cornerRadius: CornerRadius.lg, padding: Spacing.md) {
      HStack(spacing: Spacing.md) {
        AuthorAvatarView(
          displayName: store.user?.displayName ?? DomainConstants.fallbackUserDisplayPrefix,
          colorHex: store.user?.color ?? DomainConstants.defaultAuthorColor,
          size: DesignMetrics.avatarLargeSize
        )
        VStack(alignment: .leading, spacing: Spacing.xxs) {
          Text(store.user?.displayName ?? DomainConstants.fallbackUserDisplayPrefix)
            .font(Typography.cardTitle)
          if let shortTag = store.user?.shortTag {
            Text("#\(shortTag)")
              .font(Typography.caption)
              .foregroundStyle(.secondary)
          }
        }
        Spacer()
      }
    }
  }

  var displayNameCard: some View {
    GlassCard(cornerRadius: CornerRadius.lg, padding: Spacing.md) {
      VStack(alignment: .leading, spacing: Spacing.sm) {
        Text(L10n.string("profile.name.label"))
          .font(Typography.subheadline)
          .foregroundStyle(.secondary)

        TextField(
          L10n.string("profile.name.label"),
          text: Binding(
            get: { store.displayNameInput },
            set: { store.send(.displayNameChanged($0)) }
          )
        )
        .textFieldStyle(.roundedBorder)

        if store.showNameSavedFeedback {
          Label(L10n.string("profile.name.saved"), systemImage: "checkmark.circle.fill")
            .font(Typography.caption)
            .foregroundStyle(.green)
        }

        GlassActionButton(
          title: L10n.string("profile.name.save"),
          systemImage: "checkmark",
          variant: .primary,
          isLoading: store.isSavingName,
          isDisabled: store.isBusy
        ) {
          store.send(.saveDisplayNameTapped)
        }
      }
    }
  }

  var themePickerCard: some View {
    GlassCard(cornerRadius: CornerRadius.lg, padding: Spacing.md) {
      VStack(alignment: .leading, spacing: Spacing.sm) {
        Text(L10n.string("profile.theme.picker"))
          .font(Typography.subheadline)
          .foregroundStyle(.secondary)

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
        .pickerStyle(.segmented)
      }
    }
  }

  var accountActionsCard: some View {
    GlassCard(cornerRadius: CornerRadius.lg, padding: Spacing.md) {
      VStack(spacing: Spacing.sm) {
        GlassActionButton(
          title: L10n.string("profile.sign.out"),
          systemImage: "rectangle.portrait.and.arrow.right",
          variant: .secondary,
          isLoading: store.isSigningOut,
          isDisabled: store.isBusy
        ) {
          store.send(.signOutTapped)
        }

        GlassActionButton(
          title: L10n.string("profile.delete.account"),
          systemImage: "trash",
          variant: .destructive,
          isLoading: store.isDeletingAccount,
          isDisabled: store.isBusy
        ) {
          store.send(.deleteAccountTapped)
        }
      }
    }
  }

  func errorBanner(_ message: String) -> some View {
    GlassCard(cornerRadius: CornerRadius.md, padding: Spacing.sm) {
      HStack(spacing: Spacing.sm) {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.yellow)
        Text(message)
          .font(Typography.callout)
          .frame(maxWidth: .infinity, alignment: .leading)
        Button {
          store.send(.dismissError)
        } label: {
          Image(systemName: "xmark")
        }
        .buttonStyle(.plain)
      }
    }
  }
}
