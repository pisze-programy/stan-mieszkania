import DesignSystem
import SwiftUI

struct DeleteAccountImpactSheetView: View {
  let step: DeleteAccountStep
  let isDeleting: Bool
  let onContinue: () -> Void
  let onConfirm: () -> Void
  let onCancel: () -> Void

  var body: some View {
    ConfirmationSheetView(
      content: content,
      isConfirming: step == .finalConfirm && isDeleting,
      onConfirm: step == .impact ? onContinue : onConfirm,
      onCancel: onCancel
    )
  }

  private var content: ConfirmationSheetContent {
    switch step {
    case .impact:
      return ConfirmationSheetContent(
        systemImage: "exclamationmark.shield.fill",
        title: L10n.string("profile.delete.confirm.title"),
        message: L10n.string("profile.delete.confirm.message"),
        confirmTitle: L10n.string("profile.delete.step1.continue"),
        tone: .destructive
      )
    case .finalConfirm:
      return ConfirmationSheetContent(
        systemImage: "trash.fill",
        title: L10n.string("profile.delete.step2.title"),
        message: L10n.string("profile.delete.step2.message"),
        confirmTitle: L10n.string("profile.delete.step2.confirm"),
        tone: .destructive
      )
    }
  }
}
