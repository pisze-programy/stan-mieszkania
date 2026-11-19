import DesignSystem
import SwiftUI

struct LocalDevLoginSheetView: View {
  private static let defaultDevUid: String = "dev-user-1"

  @State private var firebaseUid: String = Self.defaultDevUid
  @State private var displayName: String = ""

  let onSubmit: (String, String?) -> Void
  let onCancel: () -> Void

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("UID", text: $firebaseUid)
          TextField(L10n.string("profile.name.label"), text: $displayName)
        }
      }
      .navigationTitle(L10n.string("onboarding.dev.login"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.string("apartments.create.cancel.cta"), action: onCancel)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(L10n.string("apartments.join.cta")) {
            let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            onSubmit(firebaseUid, trimmedName.isEmpty ? nil : trimmedName)
          }
          .disabled(firebaseUid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }
}
