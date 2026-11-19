import Domain
import SwiftUI

public struct AuthorAvatarView: View {
  private static let fontScaleFactor: CGFloat = 0.42

  private let displayName: String
  private let colorHex: String
  private let size: CGFloat

  public init(
    displayName: String,
    colorHex: String,
    size: CGFloat = DesignMetrics.avatarMediumSize
  ) {
    self.displayName = displayName
    self.colorHex = colorHex
    self.size = size
  }

  public var body: some View {
    Text(AuthorBadgePolicy.initials(for: displayName))
      .font(.system(size: size * Self.fontScaleFactor, weight: .bold))
      .foregroundStyle(AuthorPalette.contrastingForegroundColor(forBackgroundHex: colorHex))
      .frame(width: size, height: size)
      .background(AuthorPalette.color(fromHex: colorHex), in: .circle)
      .accessibilityLabel(displayName)
  }
}
