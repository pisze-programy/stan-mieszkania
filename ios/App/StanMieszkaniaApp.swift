import ComposableArchitecture
import SwiftUI

@main
struct StanMieszkaniaApp: App {
  private let store: StoreOf<AppFeature>?

  init() {
    if AppDependencies.isRunningTests {
      self.store = nil
    } else {
      self.store = Store(initialState: AppFeature.State()) {
        AppFeature()
      } withDependencies: { dependencies in
        AppDependencies.configureLive(&dependencies, bundle: .main)
      }
    }
  }

  var body: some Scene {
    WindowGroup {
      if let store {
        AppRootView(store: store)
      } else {
        EmptyView()
      }
    }
  }
}
