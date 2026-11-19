import Testing

@testable import DesignSystem

@Suite("DesignTokens and Haptics Tests")
struct DesignTokensAndHapticsTests {
  @Test("Maintains monotonic spacing and corner radius scales and Q14 marker opacities")
  func tokenInvariants() {
    #expect(Spacing.xxs < Spacing.xs)
    #expect(Spacing.xs < Spacing.sm)
    #expect(Spacing.sm < Spacing.md)
    #expect(Spacing.md < Spacing.lg)
    #expect(Spacing.lg < Spacing.xl)
    #expect(Spacing.xl < Spacing.xxl)

    #expect(CornerRadius.xs < CornerRadius.sm)
    #expect(CornerRadius.sm < CornerRadius.md)
    #expect(CornerRadius.md < CornerRadius.lg)
    #expect(CornerRadius.lg < CornerRadius.xl)
    #expect(CornerRadius.xl < CornerRadius.pill)

    #expect(DesignMetrics.dimmedMarkerOpacity < DesignMetrics.selectedMarkerOpacity)
    #expect(DesignMetrics.selectedMarkerOpacity == 1.0)
  }

  @MainActor
  @Test("Executes HapticsClient.noop triggers cleanly on MainActor")
  func hapticsNoopExecutes() {
    let haptics = HapticsClient.noop
    haptics.selection()
    haptics.markerDropped()
    haptics.actionSucceeded()
    haptics.warning()
    haptics.error()
  }
}
