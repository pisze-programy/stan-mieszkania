import ComposableArchitecture
import DesignSystem
import SwiftUI

public struct OnboardingView: View {
  private static let heroIconSize: CGFloat = 44

  @Bindable private var store: StoreOf<OnboardingFeature>

  public init(store: StoreOf<OnboardingFeature>) {
    self.store = store
  }

  public var body: some View {
    ZStack {
      AmbientVideoBackgroundView(videoURL: store.backgroundVideoURL)

      VStack(alignment: .leading, spacing: Spacing.lg) {
        Spacer()

        VStack(alignment: .leading, spacing: Spacing.sm) {
          Image(systemName: "building.2.crop.circle.fill")
            .font(.system(size: Self.heroIconSize))
            .foregroundStyle(.white)

          Text(L10n.string("onboarding.headline"))
            .font(Typography.screenTitle)
            .foregroundStyle(.white)

          Text(L10n.string("onboarding.description"))
            .font(Typography.body)
            .foregroundStyle(.white.opacity(DesignMetrics.selectedMarkerOpacity))
        }

        if let errorMessage = store.errorMessage {
          GlassCard(cornerRadius: CornerRadius.md, padding: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
              Text(errorMessage)
                .font(Typography.callout)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
              Button {
                store.send(.dismissError)
              } label: {
                Image(systemName: "xmark")
              }
              .buttonStyle(.plain)
              .foregroundStyle(.white)
            }
          }
        }

        VStack(spacing: Spacing.sm) {
          GlassActionButton(
            title: L10n.string("onboarding.apple.cta"),
            systemImage: "apple.logo",
            variant: .primary,
            isLoading: store.isSigningIn
          ) {
            store.send(.signInWithAppleTapped)
          }

          if store.isLocalDevLoginEnabled {
            GlassActionButton(
              title: L10n.string("onboarding.dev.login"),
              systemImage: "hammer",
              variant: .secondary,
              isDisabled: store.isSigningIn
            ) {
              store.send(.localDevSignInSheetPresented(true))
            }
          }
        }
      }
      .padding(Spacing.lg)
    }
    .sheet(
      isPresented: $store.isLocalDevSheetPresented.sending(\.localDevSignInSheetPresented)
    ) {
      LocalDevLoginSheetView(
        onSubmit: { uid, displayName in
          store.send(.localDevSignInSubmitted(uid: uid, displayName: displayName))
        },
        onCancel: {
          store.send(.localDevSignInSheetPresented(false))
        }
      )
    }
  }
}
