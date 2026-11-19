import DesignSystem
import SwiftUI

struct DetailEntryComposerView: View {
  let composer: EntryComposerState
  let onTextChanged: (String) -> Void
  let onSubmit: () -> Void
  let onCancel: () -> Void

  var body: some View {
    SurfaceCard(cornerRadius: CornerRadius.md, padding: Spacing.sm) {
      VStack(alignment: .leading, spacing: Spacing.xs) {
        Text(L10n.string("media.marker.instruction"))
          .font(.footnote)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        TextField(
          L10n.string("media.detail.entry.placeholder"),
          text: Binding(get: { composer.text }, set: { onTextChanged($0) }),
          axis: .vertical
        )
        .lineLimit(MediaDetailConstants.composerLineMin...MediaDetailConstants.composerLineMax)
        .padding(Spacing.xs)
        .background(
          Surface.inset,
          in: .rect(cornerRadius: CornerRadius.field, style: .continuous)
        )

        StableSlot(minHeight: MediaDetailConstants.composerErrorSlotHeight) {
          if let errorMessage = composer.errorMessage {
            Text(errorMessage)
              .font(Typography.footnote)
              .foregroundStyle(.red)
          }
        }
        .animation(Motion.fade, value: composer.errorMessage)

        HStack(spacing: Spacing.sm) {
          Button(L10n.string("apartments.create.cancel.cta"), action: onCancel)
            .buttonStyle(.borderless)
            .disabled(composer.isSubmitting)
          Spacer()
          GlassActionButton(
            title: L10n.string("apartment.edit.save.cta"),
            variant: .primary,
            isLoading: composer.isSubmitting,
            expandsHorizontally: false,
            controlSize: .regular,
            action: onSubmit
          )
        }
      }
    }
  }
}
