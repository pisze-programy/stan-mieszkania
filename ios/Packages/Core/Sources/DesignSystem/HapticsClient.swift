import Dependencies
import Foundation

#if os(iOS)
  import UIKit
#endif

public struct HapticsClient: Sendable {
  public var selection: @MainActor @Sendable () -> Void
  public var markerDropped: @MainActor @Sendable () -> Void
  public var actionSucceeded: @MainActor @Sendable () -> Void
  public var warning: @MainActor @Sendable () -> Void
  public var error: @MainActor @Sendable () -> Void

  public init(
    selection: @escaping @MainActor @Sendable () -> Void = {},
    markerDropped: @escaping @MainActor @Sendable () -> Void,
    actionSucceeded: @escaping @MainActor @Sendable () -> Void,
    warning: @escaping @MainActor @Sendable () -> Void,
    error: @escaping @MainActor @Sendable () -> Void
  ) {
    self.selection = selection
    self.markerDropped = markerDropped
    self.actionSucceeded = actionSucceeded
    self.warning = warning
    self.error = error
  }

  public static let noop = HapticsClient(
    selection: {},
    markerDropped: {},
    actionSucceeded: {},
    warning: {},
    error: {}
  )

  public static let live: HapticsClient = {
    #if os(iOS)
      return HapticsClient(
        selection: {
          let generator = UISelectionFeedbackGenerator()
          generator.selectionChanged()
        },
        markerDropped: {
          let generator = UIImpactFeedbackGenerator(style: .medium)
          generator.impactOccurred()
        },
        actionSucceeded: {
          let generator = UINotificationFeedbackGenerator()
          generator.notificationOccurred(.success)
        },
        warning: {
          let generator = UINotificationFeedbackGenerator()
          generator.notificationOccurred(.warning)
        },
        error: {
          let generator = UINotificationFeedbackGenerator()
          generator.notificationOccurred(.error)
        }
      )
    #else
      return .noop
    #endif
  }()
}

extension HapticsClient: DependencyKey {
  public static var liveValue: HapticsClient {
    .live
  }

  public static var testValue: HapticsClient {
    .noop
  }
}

extension DependencyValues {
  public var haptics: HapticsClient {
    get { self[HapticsClient.self] }
    set { self[HapticsClient.self] = newValue }
  }
}
