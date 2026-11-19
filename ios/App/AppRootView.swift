import ApartmentTimelineFeature
import ApartmentsListFeature
import CaptureFeature
import ComposableArchitecture
import Domain
import MediaDetailFeature
import MediaSummaryFeature
import OnboardingFeature
import ProfileFeature
import SharingFeature
import SwiftUI

public struct AppRootView: View {
  @Bindable private var store: StoreOf<AppFeature>
  @Namespace private var timelineZoomNamespace

  public init(store: StoreOf<AppFeature>) {
    self.store = store
  }

  public var body: some View {
    Group {
      if store.isForceUpdateRequired {
        ForceUpdateGateView(minVersion: store.forceUpdateMinVersion)
      } else if store.isBootstrapping {
        ProgressView()
      } else if !store.isAuthenticated {
        OnboardingView(store: store.scope(state: \.onboarding, action: \.onboarding))
      } else {
        authenticatedStack
      }
    }
    .preferredColorScheme(colorScheme(for: store.themePreference))
    .task {
      await store.send(.task).finish()
    }
  }

  // Decision S2-13: Single NavigationStack rooted at ApartmentsList with no tab bar.
  private var authenticatedStack: some View {
    Group {
      NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
        ApartmentsListView(store: store.scope(state: \.apartmentsList, action: \.apartmentsList))
      } destination: { pathStore in
        switch pathStore.case {
        case .apartmentTimeline(let timelineStore):
          ApartmentTimelineView(store: timelineStore, zoomNamespace: timelineZoomNamespace)
        case .mediaDetail(let detailStore):
          MediaDetailView(store: detailStore)
            .navigationTransition(
              .zoom(
                sourceID: "\(AppConstants.zoomTransitionSourcePrefix)\(detailStore.mediaId)",
                in: timelineZoomNamespace
              )
            )
        case .profile(let profileStore):
          ProfileView(store: profileStore)
        }
      }
      .captureFlow(store.scope(state: \.capture, action: \.capture))
    }
    .sheet(item: $store.scope(state: \.modal, action: \.modal)) { modalStore in
      switch modalStore.case {
      case .sharing(let sharingStore):
        NavigationStack {
          SharingView(store: sharingStore)
        }
      case .mediaSummary(let summaryStore):
        NavigationStack {
          MediaSummaryView(store: summaryStore)
        }
        .interactiveDismissDisabled(summaryStore.isSaving)
      }
    }
  }

  private func colorScheme(for preference: AppThemePreference) -> ColorScheme? {
    switch preference {
    case .system:
      return nil
    case .light:
      return .light
    case .dark:
      return .dark
    }
  }
}
