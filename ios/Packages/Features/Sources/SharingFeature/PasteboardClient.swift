import Dependencies
import DependenciesMacros
import Foundation

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

@DependencyClient
public struct PasteboardClient: Sendable {
  public var copyString: @MainActor @Sendable (_ text: String) -> Void = { _ in }

  public static let live: PasteboardClient = PasteboardClient(
    copyString: { text in
      #if os(iOS)
        UIPasteboard.general.string = text
      #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
      #endif
    }
  )
}

extension PasteboardClient: DependencyKey {
  public static var liveValue: PasteboardClient {
    .live
  }

  public static var testValue: PasteboardClient {
    PasteboardClient()
  }
}

extension DependencyValues {
  public var pasteboard: PasteboardClient {
    get { self[PasteboardClient.self] }
    set { self[PasteboardClient.self] = newValue }
  }
}
